const test = require("node:test");
const assert = require("node:assert/strict");
const { completeDraftJson } = require("./nexus_shared");

test("completeDraftJson uses the draft model when it works", async () => {
  const calls = [];
  const complete = async (_prompt, opts) => {
    calls.push(opts.model);
    return { ok: opts.model };
  };
  const out = await completeDraftJson("p", {
    complete,
    draftModel: "pro",
    interviewModel: "flash",
  });
  assert.deepEqual(calls, ["pro"]);
  assert.deepEqual(out, { ok: "pro" });
});

test("completeDraftJson falls back to the interview model when the draft model fails", async () => {
  const calls = [];
  const complete = async (_prompt, opts) => {
    calls.push(opts.model);
    if (opts.model === "pro") throw new Error("model not found");
    return { ok: opts.model };
  };
  const out = await completeDraftJson("p", {
    complete,
    draftModel: "pro",
    interviewModel: "flash",
  });
  assert.deepEqual(calls, ["pro", "flash"]);
  assert.deepEqual(out, { ok: "flash" });
});

test("completeDraftJson rethrows when there is no distinct fallback", async () => {
  const complete = async () => {
    throw new Error("boom");
  };
  await assert.rejects(
    () => completeDraftJson("p", { complete, draftModel: "flash", interviewModel: "flash" }),
    /boom/,
  );
});
