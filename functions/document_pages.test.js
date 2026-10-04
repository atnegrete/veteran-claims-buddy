const test = require("node:test");
const assert = require("node:assert/strict");
const { PDFDocument } = require("pdf-lib");
const {
  originalPdfPath,
  countPdfPages,
  recordPdfPageCount,
} = require("./document_pages");

test("only an original pdf path is counted", () => {
  assert.deepEqual(
    originalPdfPath("users/u1/documents/d1/original.pdf"),
    { uid: "u1", documentId: "d1" },
  );
  assert.equal(originalPdfPath("users/u1/documents/d1/original.jpg"), null);
  assert.equal(
    originalPdfPath("users/u1/documents/d1/derived/text.json"),
    null,
  );
});

test("a pdf reports how many pages it has", async () => {
  const pdf = await PDFDocument.create();
  pdf.addPage();
  pdf.addPage();
  const bytes = await pdf.save();
  assert.equal(await countPdfPages(bytes), 2);
  assert.equal(await countPdfPages(Buffer.from("not a pdf")), null);
});

test("saving a pdf records the page count and other files do not", async () => {
  const pdf = await PDFDocument.create();
  pdf.addPage();
  const bytes = await pdf.save();
  let written = null;
  await recordPdfPageCount(
    { name: "users/u1/documents/d1/original.pdf", bucket: "b" },
    {
      download: async () => bytes,
      write: async (pageCount) => {
        written = pageCount;
      },
    },
  );
  assert.equal(written, 1);

  let downloaded = false;
  await recordPdfPageCount(
    { name: "users/u1/documents/d1/original.jpg" },
    {
      download: async () => {
        downloaded = true;
        return Buffer.from([]);
      },
    },
  );
  assert.equal(downloaded, false);
});
