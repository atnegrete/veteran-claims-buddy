// The Nexus Letters gap interview. One grounded question at a time, phrased by
// Gemini, over the per-kind interviewSlots in the knowledge pack. Slots the
// saved facts already answer are seeded and skipped. State lives in one
// document per condition; the client never writes it. Nothing files with the VA.
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { loadNexusContext } = require("./nexus_letter");
const { loadPack } = require("./nexus_knowledge");
const { blockedIdentifier } = require("./vet_buddy");
const shared = require("./nexus_shared");

// Pure: the prompt that turns one slot into one plain-language question.
function questionPrompt(context, nexusKind, slot, answered) {
  return [
    "You are running a short, friendly interview to gather the facts for a VA nexus letter about one medical condition.",
    'Ask the veteran ONE clear question in plain language, addressed as "you", in one or two sentences.',
    "Ask only about the topic given. Do not explain the law, do not give advice, and do not ask for a Social Security number or an account number.",
    `Condition: ${context.condition}`,
    `Letter type: ${nexusKind}`,
    `Topic to ask about: ${slot.label} - ${slot.guidance}`,
    `What the veteran has already told you (JSON, may be empty):\n${JSON.stringify(answered)}`,
    'Reply with JSON only: {"question":"...","help":"..."} where help is an optional hint under 120 characters or "".',
  ].join("\n\n");
}

async function generateQuestion(context, nexusKind, slot, answered, deps) {
  try {
    const complete = deps.completeJson ?? shared.completeJson;
    const data = await complete(questionPrompt(context, nexusKind, slot, answered));
    const question = typeof data.question === "string" ? data.question.trim() : "";
    const help = typeof data.help === "string" ? data.help.trim() : "";
    if (question) {
      return { prompt: shared.clip(question, 400), help: shared.clip(help, 120) };
    }
  } catch (_) {
    // Fall back to the slot's own guidance so the interview never stalls.
  }
  return { prompt: shared.clip(slot.guidance, 400), help: "" };
}

// Pure: a slot is resolved once it is seeded from facts or the veteran has
// submitted an answer for it (an empty answer counts as "skipped").
function resolvedSlotIds(transcript) {
  const ids = new Set();
  for (const entry of transcript) {
    if (entry.seeded || entry.resolved) ids.add(entry.slotId);
  }
  return ids;
}

async function nexusInterviewStepHandler(request, deps = {}) {
  const uid = await (deps.requireReady ?? shared.requireReady)(request);
  const data = request.data || {};
  const caseId = data.caseId;
  const issueId = shared.clip(data.issueId, 128);
  const nexusKind =
    shared.clip(typeof data.nexusKind === "string" ? data.nexusKind : "", 40) || "direct";
  const restart = data.restart === true;
  if (typeof caseId !== "string" || caseId.length < 1 || caseId.length > 128) {
    throw new HttpsError("invalid-argument", "That claim could not be opened.");
  }
  if (!issueId) {
    throw new HttpsError("invalid-argument", "That condition could not be opened.");
  }

  const db = deps.firestore ?? getFirestore();
  const account = await db.doc(`users/${uid}`).get();
  if (account.exists && account.data().accountStatus === "deletionScheduled") {
    throw new HttpsError("failed-precondition", "This account is scheduled for deletion.");
  }

  const context = await (deps.loadNexusContext ?? loadNexusContext)(db, uid, caseId, issueId);
  if (!context) {
    throw new HttpsError("not-found", "That condition is not on this claim.");
  }

  const pack = deps.pack ?? loadPack();
  const slots = shared.interviewSlotsFor(pack, nexusKind);

  const ref = db.doc(shared.stateDocPath(uid, issueId));
  let state = null;
  if (!restart) {
    const snap = await ref.get();
    state = snap.exists ? snap.data() : null;
  }
  if (!state || state.kind !== nexusKind) {
    state = {
      kind: nexusKind,
      interview: { transcript: [], complete: false },
      doctorLetter: null,
      vetLetter: null,
    };
  }
  const transcript = Array.isArray(state.interview?.transcript)
    ? state.interview.transcript.map((entry) => ({ ...entry }))
    : [];

  // Seed the slots the saved facts already answer (idempotent).
  for (const slot of slots) {
    const seed = shared.slotSeed(context, slot.id);
    const already = transcript.some(
      (entry) => entry.slotId === slot.id && (entry.seeded || entry.resolved),
    );
    if (seed && !already) {
      transcript.push({
        slotId: slot.id,
        question: "",
        answer: shared.clip(seed, shared.maxAnswerChars),
        seeded: true,
        resolved: true,
      });
    }
  }

  // Record the answer to the question that is currently open, if any.
  if (typeof data.answer === "string") {
    const pending = [...transcript]
      .reverse()
      .find((entry) => !entry.seeded && !entry.resolved);
    if (pending) {
      const answer = shared.clip(data.answer, shared.maxAnswerChars);
      if (blockedIdentifier(answer)) {
        throw new HttpsError(
          "invalid-argument",
          "Don't include a Social Security number or a long account number.",
        );
      }
      pending.answer = answer;
      pending.resolved = true;
    }
  }

  const askSlots = slots.filter((slot) => !shared.slotSeed(context, slot.id));
  const resolved = resolvedSlotIds(transcript);

  // A question that was asked but not yet answered (e.g. the client reloaded).
  let open = transcript.find((entry) => !entry.seeded && !entry.resolved) || null;
  if (!open) {
    const nextSlot = askSlots.find((slot) => !resolved.has(slot.id));
    if (nextSlot) {
      const answered = shared.answeredFrom(transcript);
      const question = await generateQuestion(context, nexusKind, nextSlot, answered, deps);
      open = {
        slotId: nextSlot.id,
        question: question.prompt,
        help: question.help,
        answer: "",
        seeded: false,
        resolved: false,
      };
      transcript.push(open);
    }
  }

  const complete = !open;
  state.kind = nexusKind;
  state.interview = { transcript, complete };
  if (restart) {
    state.doctorLetter = null;
    state.vetLetter = null;
  }
  state.updatedAt = FieldValue.serverTimestamp();
  await ref.set(state, { merge: false });

  const answeredCount = askSlots.filter((slot) => resolved.has(slot.id)).length;
  return {
    done: complete,
    question: open
      ? { slotId: open.slotId, prompt: open.question, help: open.help || "" }
      : null,
    progress: { answered: answeredCount, total: askSlots.length },
    kind: nexusKind,
  };
}

const nexusInterviewStep = onCall(
  { timeoutSeconds: 120, memory: "512MiB" },
  (request) => nexusInterviewStepHandler(request),
);

module.exports = {
  nexusInterviewStep,
  nexusInterviewStepHandler,
  questionPrompt,
  resolvedSlotIds,
};
