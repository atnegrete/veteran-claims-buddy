const test = require("node:test");
const assert = require("node:assert/strict");
const { readUploadedDocument } = require("./document_read");

test("a file with no claim record is left alone", async () => {
  let generated = false;
  const ref = {
    async get() {
      return { exists: false, data: () => undefined };
    },
  };
  const db = {
    doc() {
      return ref;
    },
    async runTransaction(run) {
      return run({
        get: (target) => target.get(),
        set() {
          throw new Error("should not write");
        },
        update() {
          throw new Error("should not write");
        },
      });
    },
  };
  await readUploadedDocument(
    { name: "users/u/documents/d/original.pdf", bucket: "b" },
    {
      firestore: db,
      attempts: 1,
      generate: async () => {
        generated = true;
        return "";
      },
    },
  );
  assert.equal(generated, false);
});
