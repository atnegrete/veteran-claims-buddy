const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { PDFDocument } = require("pdf-lib");

function originalPdfPath(name) {
  if (typeof name !== "string") return null;
  const match = /^users\/([^/]+)\/documents\/([^/]+)\/original\.pdf$/.exec(
    name,
  );
  if (!match) return null;
  return { uid: match[1], documentId: match[2] };
}

async function countPdfPages(bytes) {
  try {
    const doc = await PDFDocument.load(bytes, { ignoreEncryption: true });
    const count = doc.getPageCount();
    if (!Number.isInteger(count) || count < 1) return null;
    return count;
  } catch {
    return null;
  }
}

async function recordPdfPageCount(object, deps = {}) {
  const parsed = originalPdfPath(object && object.name);
  if (!parsed) return;
  const download =
    deps.download ??
    (async () => {
      const bucket = getStorage().bucket(object.bucket);
      const [bytes] = await bucket.file(object.name).download();
      return bytes;
    });
  const write =
    deps.write ??
    (async (pageCount) => {
      try {
        await getFirestore()
          .doc(`users/${parsed.uid}/documents/${parsed.documentId}`)
          .update({
            pageCount,
            updatedAt: FieldValue.serverTimestamp(),
          });
      } catch (error) {
        if (error && (error.code === 5 || error.code === "not-found")) return;
        throw error;
      }
    });
  const bytes = await download();
  const pageCount = await countPdfPages(bytes);
  if (pageCount == null) return;
  await write(pageCount);
}

module.exports = {
  originalPdfPath,
  countPdfPages,
  recordPdfPageCount,
};
