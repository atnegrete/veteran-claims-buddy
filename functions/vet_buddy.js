const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { VertexAI } = require("@google-cloud/vertexai");
const { assertEnrollmentConfirmed } = require("./auth_state");
const { sessionMinutes, snapshotCharBudget } = require("./vet_buddy_config");

const modelName = "gemini-2.5-flash";

const sectionTargets = {
  questions: "Questions",
  issues: "Issues",
  documents: "Documents",
  forms: "Forms",
  package: "Package",
  exams: "C&P Prep",
  decisions: "Decisions",
};

function blockedIdentifier(text) {
  if (typeof text !== "string") return null;
  if (/\b\d{3}-\d{2}-\d{4}\b/.test(text)) return "ssn";
  if (/\b\d{9}\b/.test(text)) return "ssn";
  if (/\b\d{13,}\b/.test(text)) return "account";
  return null;
}

function clip(value, max) {
  if (typeof value !== "string") return "";
  const trimmed = value.trim();
  return trimmed.length <= max ? trimmed : trimmed.slice(0, max);
}

function statementFromFact(data) {
  if (!data) return null;
  if (data.reviewStatus !== "confirmed" && data.reviewStatus !== "corrected") {
    return null;
  }
  const corrected =
    data.reviewStatus === "corrected" ? clip(data.correctedText, 500) : "";
  const text = corrected || clip(data.factText, 500);
  if (!text) return null;
  return {
    text,
    page: Number.isInteger(data.page) && data.page > 0 ? data.page : null,
  };
}

function snapshotBody(issues, documents, statements) {
  return { issues, documents, confirmedStatements: statements };
}

function caseSnapshot(input, charBudget = snapshotCharBudget) {
  const issueRows = (input.issues || [])
    .map((issue) => ({
      id: clip(issue.id, 120),
      name: clip(issue.displayName || issue.name, 120),
    }))
    .filter((issue) => issue.id && issue.name);
  const documentRows = (input.documents || [])
    .filter((document) => document.uploadStatus === "uploaded")
    .map((document) => ({
      id: clip(document.id, 120),
      name: clip(document.name, 120),
      kind: clip(document.documentType || document.kind, 40),
    }))
    .filter((document) => document.id && document.name);
  const statementRows = (input.statements || [])
    .map((statement) => {
      const text = clip(statement.text, 500);
      if (!text) return null;
      const row = {
        documentName: clip(statement.documentName, 120),
        text,
        page:
          Number.isInteger(statement.page) && statement.page > 0
            ? statement.page
            : null,
      };
      const documentId = clip(statement.documentId, 120);
      if (documentId) row.documentId = documentId;
      return row;
    })
    .filter(Boolean);

  const issues = [];
  const documents = [];
  const confirmedStatements = [];
  let snapshotTruncated = false;

  function tryAdd(list, row) {
    const next = snapshotBody(
      list === issues ? [...issues, row] : issues,
      list === documents ? [...documents, row] : documents,
      list === confirmedStatements ? [...confirmedStatements, row] : confirmedStatements,
    );
    if (JSON.stringify(next).length > charBudget) {
      snapshotTruncated = true;
      return false;
    }
    list.push(row);
    return true;
  }

  for (const row of issueRows) {
    if (!tryAdd(issues, row)) break;
  }
  if (!snapshotTruncated) {
    for (const row of documentRows) {
      if (!tryAdd(documents, row)) break;
    }
  }
  if (!snapshotTruncated) {
    for (const row of statementRows) {
      if (!tryAdd(confirmedStatements, row)) break;
    }
  }
  if (
    !snapshotTruncated &&
    (issues.length < issueRows.length ||
      documents.length < documentRows.length ||
      confirmedStatements.length < statementRows.length)
  ) {
    snapshotTruncated = true;
  }

  return {
    ...snapshotBody(issues, documents, confirmedStatements),
    snapshotTruncated,
  };
}

function safeReply(text) {
  const value = clip(text, 4000);
  if (!value) return "That is not in this claim yet.";
  if (
    /i (have )?filed (this |your )?claim|your claim is approved|\d+\s*%\s*chance/i.test(
      value,
    )
  ) {
    return "I can explain what is saved on this claim. I cannot file it, decide it, or give a chance of approval.";
  }
  return value;
}

function acceptedLinks(links, snapshot) {
  if (!Array.isArray(links)) return [];
  const issues = new Map(
    (snapshot.issues || [])
      .filter((issue) => issue && issue.id)
      .map((issue) => [issue.id, issue.name || ""]),
  );
  const documents = new Map(
    (snapshot.documents || [])
      .filter((document) => document && document.id)
      .map((document) => [document.id, document.name || ""]),
  );
  const kept = [];
  const seen = new Set();
  for (const link of links) {
    if (!link || typeof link !== "object") continue;
    const target = link.target;
    let row = null;
    if (Object.prototype.hasOwnProperty.call(sectionTargets, target)) {
      row = {
        target,
        label: clip(link.label, 80) || sectionTargets[target],
      };
    } else if (target === "issue" && issues.has(link.issueId)) {
      const label = clip(link.label, 80) || issues.get(link.issueId);
      if (label) row = { target, label, issueId: link.issueId };
    } else if (target === "document" && documents.has(link.documentId)) {
      const label = clip(link.label, 80) || documents.get(link.documentId);
      if (label) row = { target, label, documentId: link.documentId };
    }
    if (!row) continue;
    const key = `${row.target}:${row.issueId || ""}:${row.documentId || ""}`;
    if (seen.has(key)) continue;
    seen.add(key);
    kept.push(row);
    if (kept.length >= 6) break;
  }
  return kept;
}

function expiresMillis(value) {
  if (value == null) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (typeof value === "number") return value;
  return 0;
}

function sessionIsOpen(expiresAt, now) {
  return expiresMillis(expiresAt) > now;
}

function parsedReply(text) {
  const raw = typeof text === "string" ? text.trim() : "";
  const start = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  const body = start >= 0 && end > start ? raw.slice(start, end + 1) : raw;
  try {
    const data = JSON.parse(body);
    if (data && typeof data.reply === "string") {
      return {
        reply: data.reply,
        links: Array.isArray(data.links) ? data.links : [],
      };
    }
  } catch (_) {
    // The model sometimes answers in prose. Keep that prose and drop links.
  }
  return { reply: raw, links: [] };
}

function guardedReply(reply, links, snapshot) {
  const content = safeReply(reply);
  const kept =
    content === clip(reply, 4000) ? acceptedLinks(links, snapshot) : [];
  return { content, links: kept };
}

const instructions = [
  "You are Vet Buddy, inside a private claim worksheet.",
  "Explain only what is in the claim snapshot and this session.",
  "Do not change the claim, and do not say that you changed it.",
  "Do not file a claim, decide a claim, predict a rating, give a legal deadline, or say that a form or appointment is current.",
  "If the snapshot does not contain the answer, say that it is not in the claim yet.",
  "Do not ask for a Social Security number, bank account, password, or authentication code.",
  "Do not give a percentage chance of approval.",
  "The snapshot is not a medical opinion and nothing in it has been filed with the VA.",
  "When the Veteran should open a screen, add a link from the allowed list.",
  "Use only those targets and ids. Do not invent a path or a web address.",
].join(" ");

function linkCatalog(snapshot) {
  const lines = Object.entries(sectionTargets).map(
    ([target, label]) => `${target}: ${label}`,
  );
  for (const issue of snapshot.issues || []) {
    if (issue.id && issue.name) lines.push(`issue ${issue.id}: ${issue.name}`);
  }
  for (const document of snapshot.documents || []) {
    if (document.id && document.name) {
      lines.push(`document ${document.id}: ${document.name}`);
    }
  }
  return lines.join("\n");
}

function modelContents({ snapshot, snapshotTruncated, history, question }) {
  const intro = [
    instructions,
    snapshotTruncated
      ? "The snapshot was cut off. If the answer may be in what was left out, say that the list was cut."
      : "",
    `Claim snapshot:\n${JSON.stringify(snapshot)}`,
    `Allowed links:\n${linkCatalog(snapshot)}`,
    'Reply with JSON only: {"reply":"...","links":[{"target":"questions|issues|documents|forms|package|exams|decisions|issue|document","label":"...","issueId":"only for an issue","documentId":"only for a document"}]}',
  ]
    .filter(Boolean)
    .join("\n\n");
  const turns = Array.isArray(history) ? history : [];
  if (turns.length === 0) {
    return [
      {
        role: "user",
        parts: [{ text: `${intro}\n\nQuestion:\n${question}` }],
      },
    ];
  }
  const [first, ...rest] = turns;
  const contents = [
    {
      role: "user",
      parts: [
        {
          text: `${intro}\n\nQuestion:\n${first.role === "assistant" ? "" : first.content || ""}`,
        },
      ],
    },
  ];
  if (first.role === "assistant") {
    contents.push({ role: "model", parts: [{ text: first.content || "" }] });
  }
  for (const turn of rest) {
    contents.push({
      role: turn.role === "assistant" ? "model" : "user",
      parts: [{ text: turn.content || "" }],
    });
  }
  contents.push({ role: "user", parts: [{ text: question }] });
  return contents;
}

function projectId() {
  return process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT;
}

async function generateReply({ question, snapshot, history, snapshotTruncated }) {
  const vertex = new VertexAI({
    project: projectId(),
    location: "us-central1",
  });
  const model = vertex.getGenerativeModel({
    model: modelName,
    generationConfig: {
      temperature: 0.2,
      responseMimeType: "application/json",
    },
  });
  const result = await model.generateContent({
    contents: modelContents({
      snapshot,
      snapshotTruncated,
      history,
      question,
    }),
  });
  const parts = result.response?.candidates?.[0]?.content?.parts ?? [];
  return parsedReply(parts.map((part) => part.text ?? "").join(""));
}

function storedSnapshot(loaded) {
  return {
    issues: loaded.issues || [],
    documents: loaded.documents || [],
    confirmedStatements: loaded.confirmedStatements || [],
  };
}

async function loadSnapshot(db, uid, caseId) {
  const caseDoc = await db.doc(`users/${uid}/cases/${caseId}`).get();
  if (!caseDoc.exists) return null;
  const [issueSnap, documentSnap] = await Promise.all([
    db
      .collection(`users/${uid}/claimIssues`)
      .where("activeCaseId", "==", caseId)
      .get(),
    db.collection(`users/${uid}/documents`).where("caseId", "==", caseId).get(),
  ]);
  const uploaded = documentSnap.docs.filter(
    (document) => document.data().uploadStatus === "uploaded",
  );
  const groups = await Promise.all(
    uploaded.map(async (document) => {
      const facts = await document.ref.collection("facts").get();
      const rows = [];
      for (const fact of facts.docs) {
        const row = statementFromFact(fact.data());
        if (!row) continue;
        rows.push({
          documentId: document.id,
          documentName: clip(document.data().name, 120),
          ...row,
        });
      }
      return rows;
    }),
  );
  return caseSnapshot({
    issues: issueSnap.docs.map((doc) => ({ ...doc.data(), id: doc.id })),
    documents: uploaded.map((doc) => ({ ...doc.data(), id: doc.id })),
    statements: groups.flat(),
  });
}

function messageTime(data) {
  return expiresMillis(data.createdAt);
}

async function sessionHistory(messages, sessionId) {
  const snap = await messages.where("sessionId", "==", sessionId).get();
  return snap.docs
    .map((doc) => doc.data())
    .filter((data) => data.role === "user" || data.role === "assistant")
    .sort((a, b) => messageTime(a) - messageTime(b))
    .map((data) => ({ role: data.role, content: data.content || "" }));
}

async function requireReady(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const user = await getAuth().getUser(request.auth.uid);
  if (!assertEnrollmentConfirmed(user).ok) {
    throw new HttpsError(
      "failed-precondition",
      "Verified email and an enrolled text-message check are required.",
    );
  }
  return request.auth.uid;
}

async function askVetBuddyHandler(request, deps = {}) {
  const ready = deps.requireReady ?? requireReady;
  const uid = await ready(request);
  const data = request.data || {};
  const caseId = data.caseId;
  const endSession = data.endSession === true;
  const text = typeof data.text === "string" ? data.text.trim() : "";
  if (typeof caseId !== "string" || caseId.length < 1 || caseId.length > 128) {
    throw new HttpsError("invalid-argument", "That claim could not be opened.");
  }
  if (!endSession && (text.length < 1 || text.length > 2000)) {
    throw new HttpsError(
      "invalid-argument",
      "Ask a question in 2000 characters or less.",
    );
  }
  if (!endSession && blockedIdentifier(text)) {
    throw new HttpsError(
      "invalid-argument",
      "Don't send a Social Security number or a long account number in chat.",
    );
  }
  const db = deps.firestore ?? getFirestore();
  const account = await db.doc(`users/${uid}`).get();
  if (account.exists && account.data().accountStatus === "deletionScheduled") {
    throw new HttpsError(
      "failed-precondition",
      "This account is scheduled for deletion.",
    );
  }
  const now = deps.now ? deps.now() : Date.now();
  const minutes = deps.sessionMinutes ?? sessionMinutes;
  const chatRef = db.doc(`users/${uid}/chats/${caseId}`);
  const chatSnap = await chatRef.get();
  const chat = chatSnap.exists ? chatSnap.data() : null;

  if (endSession) {
    const endedAt = Timestamp.fromMillis(now);
    await chatRef.set(
      {
        sessionExpiresAt: endedAt,
        sessionMinutes: minutes,
      },
      { merge: true },
    );
    if (chat && chat.activeSessionId) {
      await chatRef.collection("sessions").doc(chat.activeSessionId).set(
        { expiresAt: endedAt },
        { merge: true },
      );
    }
    return { ended: true };
  }

  let session = null;
  let sessionRef = null;
  if (chat && chat.activeSessionId) {
    sessionRef = chatRef.collection("sessions").doc(chat.activeSessionId);
    const sessionSnap = await sessionRef.get();
    session = sessionSnap.exists ? sessionSnap.data() : null;
  }
  const open =
    session && sessionIsOpen(session.expiresAt, now) && session.snapshot;
  let snapshot;
  let snapshotTruncated = false;
  let sessionId;
  let startedAt;
  if (!open) {
    const load = deps.loadSnapshot ?? loadSnapshot;
    const loaded = await load(db, uid, caseId);
    if (!loaded) {
      throw new HttpsError("not-found", "That claim is not on this account.");
    }
    snapshot = storedSnapshot(loaded);
    snapshotTruncated = loaded.snapshotTruncated === true;
    sessionRef = chatRef.collection("sessions").doc();
    sessionId = sessionRef.id;
    startedAt = Timestamp.fromMillis(now);
    const expiresAt = Timestamp.fromMillis(now + minutes * 60 * 1000);
    await sessionRef.set({
      startedAt,
      expiresAt,
      lastActivityAt: startedAt,
      snapshot,
      snapshotTruncated,
    });
  } else {
    snapshot = session.snapshot;
    snapshotTruncated = session.snapshotTruncated === true;
    sessionId = chat.activeSessionId;
    startedAt = chat.sessionStartedAt || session.startedAt;
  }

  const messages = chatRef.collection("messages");
  const history = open ? await sessionHistory(messages, sessionId) : [];
  const expiresAt = Timestamp.fromMillis(now + minutes * 60 * 1000);
  const stamped = Timestamp.fromMillis(now);
  await sessionRef.set({ expiresAt, lastActivityAt: stamped }, { merge: true });
  const chatUpdate = {
    title: "This claim",
    status: "active",
    contextType: "general",
    contextId: caseId,
    activeSessionId: sessionId,
    sessionStartedAt: startedAt,
    sessionExpiresAt: expiresAt,
    sessionMinutes: minutes,
    lastMessageAt: FieldValue.serverTimestamp(),
  };
  if (!chatSnap.exists) chatUpdate.createdAt = FieldValue.serverTimestamp();
  await chatRef.set(chatUpdate, { merge: true });
  let generated;
  try {
    generated = await (deps.generate ?? generateReply)({
      question: text,
      snapshot,
      history,
      snapshotTruncated,
    });
  } catch (error) {
    console.error("vet buddy reply failed");
    throw new HttpsError("internal", "Vet Buddy could not answer. Try again.");
  }
  const reply =
    generated && typeof generated.reply === "string" ? generated.reply : "";
  const rawLinks =
    generated && Array.isArray(generated.links) ? generated.links : [];
  const guarded = guardedReply(reply, rawLinks, snapshot);
  await messages.add({
    role: "user",
    content: text,
    status: "complete",
    toolEventIds: [],
    sessionId,
    createdAt: Timestamp.fromMillis(now),
  });
  await messages.add({
    role: "assistant",
    content: guarded.content,
    links: guarded.links,
    status: "complete",
    toolEventIds: [],
    sessionId,
    createdAt: Timestamp.fromMillis(now + 1),
  });
  return { reply: guarded.content, links: guarded.links };
}

const askVetBuddy = onCall(
  { timeoutSeconds: 120, memory: "512MiB" },
  (request) => askVetBuddyHandler(request),
);

module.exports = {
  askVetBuddy,
  askVetBuddyHandler,
  acceptedLinks,
  blockedIdentifier,
  caseSnapshot,
  guardedReply,
  modelContents,
  parsedReply,
  sessionIsOpen,
  statementFromFact,
  safeReply,
};
