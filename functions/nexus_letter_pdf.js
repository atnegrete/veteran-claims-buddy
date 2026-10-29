// Renders the two Nexus Letters from scratch with pdf-lib. There is no official
// VA template for a nexus letter, so these are laid out as plain business
// letters: a physician scaffold letter (with an optional suggested-draft page)
// and a veteran-signable statement. The preview copy is watermarked by reusing
// form_generation's watermarkPdf. Nothing here files with the VA.
const { PDFDocument, StandardFonts, rgb } = require("pdf-lib");
const { watermarkPdf } = require("./form_generation");

const PAGE_W = 612;
const PAGE_H = 792;
const MARGIN = 72;
const CONTENT_W = PAGE_W - MARGIN * 2;
const BODY = 11;
const LINE = 15;
const HEAD = 12.5;
const SMALL = 9;

// Standard fonts use WinAnsi, which cannot encode smart quotes or arbitrary
// unicode. Fold the common cases to ASCII, then drop anything still outside
// the encodable range so drawText never throws.
function sanitize(text) {
  if (typeof text !== "string") return "";
  return text
    .replace(/\r\n?/g, "\n")
    .replace(/[\u2018\u2019\u2032]/g, "'")
    .replace(/[\u201C\u201D\u2033]/g, '"')
    .replace(/[\u2013\u2014]/g, "-")
    .replace(/\u2026/g, "...")
    .replace(/[\u2022\u00b7]/g, "-")
    .replace(/\u00a0/g, " ")
    .replace(/[\t\f\v]/g, " ")
    .replace(/[^\n\x20-\x7e\xa1-\xff]/g, "");
}

function hardBreak(word, font, size, maxWidth) {
  const chunks = [];
  let chunk = "";
  for (const ch of word) {
    if (chunk && font.widthOfTextAtSize(chunk + ch, size) > maxWidth) {
      chunks.push(chunk);
      chunk = ch;
    } else {
      chunk += ch;
    }
  }
  if (chunk) chunks.push(chunk);
  return chunks;
}

// Pure: wrap one block of text (honoring explicit newlines) to a pixel width.
function wrapParagraph(text, font, size, maxWidth) {
  const out = [];
  for (const rawLine of sanitize(text).split("\n")) {
    const words = rawLine.split(/\s+/).filter(Boolean);
    if (words.length === 0) {
      out.push("");
      continue;
    }
    let line = "";
    for (const word of words) {
      if (font.widthOfTextAtSize(word, size) > maxWidth) {
        if (line) {
          out.push(line);
          line = "";
        }
        const chunks = hardBreak(word, font, size, maxWidth);
        for (let i = 0; i < chunks.length - 1; i++) out.push(chunks[i]);
        line = chunks[chunks.length - 1] || "";
        continue;
      }
      const candidate = line ? `${line} ${word}` : word;
      if (font.widthOfTextAtSize(candidate, size) <= maxWidth) {
        line = candidate;
      } else {
        out.push(line);
        line = word;
      }
    }
    if (line) out.push(line);
  }
  return out;
}

// A simple top-to-bottom cursor that paginates on overflow.
class Letter {
  constructor(doc, font, bold, italic) {
    this.doc = doc;
    this.font = font;
    this.bold = bold;
    this.italicFont = italic;
    this.mode = "preview";
    this.page = doc.addPage([PAGE_W, PAGE_H]);
    this.y = PAGE_H - MARGIN;
  }

  newPage() {
    this.page = this.doc.addPage([PAGE_W, PAGE_H]);
    this.y = PAGE_H - MARGIN;
  }

  _ensure(space) {
    if (this.y - space < MARGIN) this.newPage();
  }

  gap(px) {
    this._ensure(px);
    this.y -= px;
  }

  line(text, { font, size = BODY, leading = LINE, color } = {}) {
    const face = font || this.font;
    for (const wrapped of wrapParagraph(text, face, size, CONTENT_W)) {
      this._ensure(leading);
      if (wrapped) {
        this.page.drawText(wrapped, {
          x: MARGIN,
          y: this.y,
          size,
          font: face,
          color: color || rgb(0, 0, 0),
        });
      }
      this.y -= leading;
    }
  }

  paragraph(text, opts) {
    if (text && String(text).trim()) {
      this.line(String(text), opts);
      this.gap(6);
    }
  }

  heading(text) {
    this.gap(6);
    this.line(text, { font: this.bold, size: HEAD, leading: HEAD + 3 });
    this.gap(2);
  }

  title(text) {
    this.line(text, { font: this.bold, size: 15, leading: 20 });
  }

  small(text) {
    this.line(text, { size: SMALL, leading: SMALL + 3, color: rgb(0.35, 0.35, 0.35) });
  }

  // An italic line, used for the short description beneath a citation and for
  // the preview-only "to be completed" placeholders.
  italic(text, { size = BODY, leading = LINE, color } = {}) {
    this.line(text, { font: this.italicFont, size, leading, color });
  }

  // Leaves blank writing room with light ruled lines so the physician has space
  // to complete a section on the printed copy.
  fillSpace(lines = 4) {
    const step = LINE + 7;
    for (let i = 0; i < lines; i++) {
      this._ensure(step);
      this.y -= step;
      this.page.drawLine({
        start: { x: MARGIN, y: this.y + 4 },
        end: { x: PAGE_W - MARGIN, y: this.y + 4 },
        thickness: 0.4,
        color: rgb(0.78, 0.78, 0.78),
      });
    }
    this.gap(4);
  }
}

// A section the physician completes: generous blank writing space on the
// printed copy, a faint placeholder (and no ruled lines) in the preview.
function physicianBlank(letter, lines = 4) {
  if (letter.mode === "print") {
    letter.fillSpace(lines);
    return;
  }
  letter.italic("[To be completed by the physician.]", {
    size: SMALL + 1,
    color: rgb(0.45, 0.45, 0.45),
  });
  letter.gap(6);
}

// A citation (regular) followed by its short description (italic).
function citationEntry(letter, entry) {
  if (!entry || !entry.citation) return;
  letter.line(entry.citation);
  if (entry.description) {
    letter.italic(entry.description, { size: SMALL + 1, color: rgb(0.3, 0.3, 0.3) });
  }
  letter.gap(5);
}

function headerName(identity) {
  return (identity && identity.legalName) || "";
}

function drawDoctorLetter(letter, params) {
  const { identity, condition, branch, sections, basis, disclaimer } = params;
  const name = headerName(identity) || "[Veteran name]";
  const vaFile = (identity && identity.vaFileNumber) || "____________________";
  letter.title("Nexus Letter");
  letter.gap(4);
  letter.line(`Subject: Nexus letter - service connection for ${condition}`, { font: letter.bold });
  letter.gap(8);
  letter.line("Physician name: ______________________________");
  letter.line("Practice / clinic: ____________________________");
  letter.line("Address: ______________________________________");
  letter.line("Phone: ________________________________________");
  letter.line("Date: _________________________________________");
  letter.gap(10);
  letter.line("Department of Veterans Affairs");
  letter.line("Evidence Intake Center");
  letter.gap(8);
  letter.line(`RE: ${name}`);
  letter.line(`Claimed condition: ${condition}`);
  letter.line(`Branch of service: ${branch || "____________________"}`);
  letter.line(`VA file number: ${vaFile}`);
  letter.gap(8);
  letter.line("To Whom It May Concern:");
  letter.gap(8);
  letter.paragraph(sections.recordsReviewed);
  letter.heading("Clinical summary");
  letter.paragraph(sections.clinicalSummary || "[No history was provided.]");
  letter.heading("Reported in-service history");
  letter.paragraph(sections.inServiceBasis || "[No in-service history was provided.]");
  letter.heading("Current diagnosis");
  physicianBlank(letter, 3);
  letter.heading("Medical rationale");
  physicianBlank(letter, 6);
  letter.heading("Opinion (check one, then complete and sign below)");
  letter.line(
    `[  ] In my professional opinion it is at least as likely as not (50% or greater probability) that the Veteran's ${condition} is related to ${basis}.`,
  );
  letter.gap(4);
  letter.line(
    `[  ] In my professional opinion it is less likely than not that the Veteran's ${condition} is related to ${basis}.`,
  );
  letter.gap(6);
  letter.line("Comments: _____________________________________________");
  letter.gap(14);
  letter.line("Sincerely,");
  letter.gap(26);
  letter.line("_______________________________        Date: ______________");
  letter.line("Physician signature");
  letter.gap(4);
  letter.line("Printed name: _________________________________");
  letter.line("Credentials / title: __________________________");
  letter.line("License number / state: _______________________");
  letter.line("NPI: __________________________________________");
  letter.gap(16);
  letter.small(disclaimer);

  // Optional, clearly separated suggested-draft page.
  letter.newPage();
  letter.title("SUGGESTED DRAFT - OPTIONAL");
  letter.gap(4);
  letter.small(
    "The language below was generated from the veteran's account to save time. It is optional. The physician or veteran may use, edit, or ignore it. It is not a medical opinion and is asserted by no one until a clinician reviews and signs.",
  );
  letter.heading("Suggested diagnosis");
  letter.paragraph((sections.suggested && sections.suggested.diagnosis) || "[None suggested.]");
  letter.heading("Suggested medical rationale");
  letter.paragraph((sections.suggested && sections.suggested.rationale) || "[None suggested.]");
  if (Array.isArray(sections.literature) && sections.literature.length) {
    letter.heading("Relevant medical literature");
    letter.small(
      "Peer-reviewed literature the physician may consider in support of the rationale. Confirm relevance before relying on any source.",
    );
    letter.gap(2);
    for (const entry of sections.literature) citationEntry(letter, entry);
  }
  letter.gap(10);
  letter.small(disclaimer);
}

function drawVetLetter(letter, params) {
  const { identity, condition, branch, sections, disclaimer } = params;
  const name = headerName(identity) || "[Your name]";
  const vaFile = (identity && identity.vaFileNumber) || "____________________";
  letter.title("Statement in Support of Claim");
  letter.gap(4);
  letter.line(`Subject: Nexus letter - service connection for ${condition}`, { font: letter.bold });
  letter.gap(6);
  letter.line(`Name: ${name}`);
  letter.line(`Claimed condition: ${condition}`);
  letter.line(`Branch of service: ${branch || "____________________"}`);
  letter.line(`VA file number: ${vaFile}`);
  letter.line("Date: _________________________________________");
  letter.gap(10);
  letter.paragraph(sections.statement || "[No statement was provided.]");
  if (Array.isArray(sections.citations) && sections.citations.length) {
    letter.heading("Legal & Medical Citations");
    for (const entry of sections.citations) citationEntry(letter, entry);
  }
  if (sections.presumptiveNote) {
    letter.heading("Possible presumptive path");
    letter.paragraph(sections.presumptiveNote);
    if (sections.presumptiveCitation) {
      letter.italic(sections.presumptiveCitation, { size: SMALL + 1, color: rgb(0.3, 0.3, 0.3) });
    }
  }
  letter.heading("Closing Remarks");
  letter.paragraph(
    sections.closing ||
      "I respectfully ask the VA to give this claim fair and thorough consideration of all the evidence. I certify that the statements above are true and correct to the best of my knowledge and belief.",
  );
  letter.gap(22);
  letter.line("_______________________________        Date: ______________");
  letter.line(headerName(identity) || "Signature");
  letter.gap(16);
  letter.small(disclaimer);
}

async function render(draw, params, options) {
  const doc = await PDFDocument.create();
  const font = await doc.embedFont(StandardFonts.TimesRoman);
  const bold = await doc.embedFont(StandardFonts.TimesRomanBold);
  const italic = await doc.embedFont(StandardFonts.TimesRomanItalic);
  const letter = new Letter(doc, font, bold, italic);
  letter.mode = options && options.mode === "print" ? "print" : "preview";
  draw(letter, params);
  let bytes = await doc.save();
  if (options && options.watermark) bytes = await watermarkPdf(bytes);
  return bytes;
}

async function buildDoctorLetterPdf(params, options = {}) {
  return render(drawDoctorLetter, params, options);
}

async function buildVetLetterPdf(params, options = {}) {
  return render(drawVetLetter, params, options);
}

module.exports = {
  buildDoctorLetterPdf,
  buildVetLetterPdf,
  wrapParagraph,
  sanitize,
};
