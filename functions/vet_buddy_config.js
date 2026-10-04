/** Minutes a Vet Buddy session stays open after the last message. */
const sessionMinutes = 15;

/** Largest claim snapshot, in characters, stored for one session. */
const snapshotCharBudget = 100000;

module.exports = { sessionMinutes, snapshotCharBudget };
