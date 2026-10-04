const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { VertexAI } = require("@google-cloud/vertexai");
const { recordPdfPageCount } = require("./document_pages");
const {
  shouldStartRead,
  factsFromModelText,
  factPrompt,
} = require("./document_facts");
const {
  decisionFromModelText,
  decisionPrompt,
  saveDecisionDraft,
} = require("./decision_letter");

const modelName = "gemini-2.5-flash";

function originalDocumentPath(name) {
  if (typeof name !== "string") return null;
  const match = /^users\/([^/]+)\/documents\/([^/]+)\/original\.(pdf|jpg|png)$/.exec(
    name,
  );
  if (!match) return null;
  const extension = match[3];
  const contentType =
    extension === "pdf"
      ? "application/pdf"
      : extension === "jpg"
        ? "image/jpeg"
        : "image/png";
  return { uid: match[1], documentId: match[2], extension, contentType };
}

function projectId() {
  return process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT;
}

async function generateFacts({ fileUri, mimeType, prompt }) {
  const vertex = new VertexAI({
    project: projectId(),
    location: "us-central1",
  });
  const model = vertex.getGenerativeModel({
    model: modelName,
    generationConfig: {
      temperature: 0,
      responseMimeType: "application/json",
    },
  });
  const result = await model.generateContent({
    contents: [
      {
        role: "user",
        parts: [
          { text: prompt || factPrompt },
          { fileData: { mimeType, fileUri } },
        ],
      },
    ],
  });
  const parts = result.response?.candidates?.[0]?.content?.parts ?? [];
  return parts.map((part) => part.text ?? "").join("");
}

function retryable(error) {
  const message = String(error && error.message ? error.message : error);
  return /UNAVAILABLE|DEADLINE|RESOURCE_EXHAUSTED|429|500|503/.test(message);
}

function missingDocument(error) {
  return Boolean(error && (error.code === 5 || error.code === "not-found"));
}

async function waitForDocument(docRef, deps) {
  const attempts = deps.attempts ?? 15;
  const wait =
    deps.wait ?? ((ms) => new Promise((resolve) => setTimeout(resolve, ms)));
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const snap = await docRef.get();
    if (snap.exists) return snap;
    if (attempt < attempts - 1) await wait(1000);
  }
  return null;
}

async function readUploadedDocument(object, deps = {}) {
  const parsed = originalDocumentPath(object && object.name);
  if (!parsed || !object.bucket) return;
  const db = deps.firestore ?? getFirestore();
  const docRef = db.doc(`users/${parsed.uid}/documents/${parsed.documentId}`);
  const jobRef = db.doc(
    `users/${parsed.uid}/processingJobs/${parsed.documentId}`,
  );
  const nowMs = deps.nowMs ?? Date.now();
  const ready = await waitForDocument(docRef, deps);
  if (!ready) return;
  let gate;
  try {
    gate = await db.runTransaction(async (tx) => {
      const [job, doc] = await Promise.all([tx.get(jobRef), tx.get(docRef)]);
      if (!doc.exists) return "missing";
      const data = job.exists ? job.data() : null;
      if (!shouldStartRead(data, nowMs)) return "skip";
      tx.set(jobRef, {
        type: "medicalRecordExtraction",
        status: "processing",
        progress: 0,
        documentId: parsed.documentId,
        startedAt: FieldValue.serverTimestamp(),
        completedAt: null,
        errorCode: null,
        safeErrorMessage: null,
        attempt: ((data && data.attempt) || 0) + 1,
        createdAt:
          data && data.createdAt
            ? data.createdAt
            : FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.update(docRef, {
        processingStatus: "processing",
        updatedAt: FieldValue.serverTimestamp(),
      });
      return "read";
    });
  } catch (error) {
    if (missingDocument(error)) return;
    throw error;
  }
  if (gate === "missing") return;
  if (gate !== "read") {
    if (parsed.extension === "pdf") {
      await recordPdfPageCount(object, deps);
    }
    return;
  }

  const fail = async () => {
    try {
      await docRef.update({
        processingStatus: "failed",
        updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (!missingDocument(error)) throw error;
    }
    await jobRef.set(
      {
        status: "failed",
        progress: 1,
        errorCode: "unreadable",
        safeErrorMessage: "That file could not be read.",
        completedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  };

  try {
    if (parsed.extension === "pdf") {
      await recordPdfPageCount(object, deps);
    }
    const record = (await docRef.get()).data() || {};
    const letter = record.documentType === "decisionLetter";
    const generate = deps.generate ?? generateFacts;
    const text = await generate({
      fileUri: `gs://${object.bucket}/${object.name}`,
      mimeType: parsed.contentType,
      prompt: letter ? decisionPrompt : factPrompt,
    });
    let parsedFacts = factsFromModelText(text);
    const parsedDecision = letter ? decisionFromModelText(text) : null;
    if (!parsedFacts.ok && letter && parsedDecision && parsedDecision.ok) {
      parsedFacts = { ok: true, facts: [] };
    }
    if (!parsedFacts.ok) {
      await fail();
      return;
    }
    if (
      letter &&
      parsedDecision &&
      !parsedDecision.ok &&
      parsedFacts.facts.length === 0
    ) {
      await fail();
      return;
    }
    const derivedName = object.name.replace(
      /original\.(pdf|jpg|png)$/,
      "derived/text.json",
    );
    const save =
      deps.saveDerived ??
      (async (body) => {
        await getStorage().bucket(object.bucket).file(derivedName).save(body, {
          contentType: "application/json",
          resumable: false,
        });
      });
    await save(
      JSON.stringify({
        statements: parsedFacts.facts.map((fact) => fact.factText),
      }),
    );
    const existing = await docRef.collection("facts").get();
    const batch = db.batch();
    for (const factDoc of existing.docs) {
      if (factDoc.data().reviewStatus === "unreviewed") {
        batch.delete(factDoc.ref);
      }
    }
    for (const fact of parsedFacts.facts) {
      batch.set(docRef.collection("facts").doc(), {
        factType: fact.factType,
        normalizedConditionId: null,
        conditionText: fact.conditionText,
        claimIssueIds: [],
        factText: fact.factText,
        correctedText: null,
        eventDate: fact.eventDate,
        page: fact.page,
        sourceStart: null,
        sourceEnd: null,
        confidence: fact.confidence,
        sourceType: "documentExtracted",
        reviewStatus: "unreviewed",
        schemaVersion: 1,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    const status =
      letter && parsedDecision && parsedDecision.ok
        ? "needsReview"
        : parsedFacts.facts.length > 0
          ? "needsReview"
          : "complete";
    batch.update(docRef, {
      processingStatus: status,
      updatedAt: FieldValue.serverTimestamp(),
    });
    batch.set(
      jobRef,
      {
        status,
        progress: 1,
        errorCode: null,
        safeErrorMessage: null,
        completedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await batch.commit();
    if (letter && parsedDecision && parsedDecision.ok && record.caseId) {
      const saveDraft = deps.saveDecision ?? saveDecisionDraft;
      await saveDraft({
        db,
        uid: parsed.uid,
        caseId: record.caseId,
        documentId: parsed.documentId,
        decision: parsedDecision.decision,
      });
    }
  } catch (error) {
    await fail();
    console.error("document read failed", parsed.documentId);
    if (retryable(error)) throw error;
  }
}

module.exports = {
  originalDocumentPath,
  readUploadedDocument,
  modelName,
};
