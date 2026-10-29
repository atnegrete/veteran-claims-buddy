const test = require("node:test");
const assert = require("node:assert/strict");
const { readPack } = require("./nexus_knowledge");
const { matchPresumptive, rangesOverlap, normalize } = require("./nexus_letter");

const pack = readPack();

test("rangesOverlap treats an empty end as present", () => {
  assert.equal(rangesOverlap("1968-01-01", "1969-01-01", "1962-01-09", "1975-05-07"), true);
  assert.equal(rangesOverlap("2000-01-01", "", "1962-01-09", "1975-05-07"), false);
});

test("normalize lowercases and strips punctuation", () => {
  assert.equal(normalize("Type 2 Diabetes!"), "type 2 diabetes");
});

test("matchPresumptive flags Agent Orange for herbicide service in Vietnam", () => {
  const result = matchPresumptive(
    {
      condition: "Type 2 diabetes",
      exposures: [{ type: "herbicide", description: "sprayed defoliant" }],
      deployments: [
        { country: "Vietnam", notes: "Da Nang", startDate: "1968-03-01", endDate: "1969-03-01" },
      ],
      service: [{ branch: "army", startDate: "1967-01-01", endDate: "1970-01-01" }],
    },
    pack,
  );
  const agentOrange = result.pathways.find((pathway) => pathway.id === "agentOrange");
  assert.ok(agentOrange, "expected the Agent Orange pathway to match");
  assert.equal(agentOrange.conditionMatch, true);
  assert.equal(result.advisory, true);
  assert.match(result.advisoryText, /presumptive/i);
});

test("matchPresumptive stays quiet for a plain stateside knee strain", () => {
  const result = matchPresumptive(
    {
      condition: "Knee strain",
      exposures: [],
      deployments: [],
      service: [{ branch: "army", startDate: "2015-01-01", endDate: "2019-01-01" }],
    },
    pack,
  );
  assert.equal(result.pathways.length, 0);
  assert.equal(result.advisory, false);
  assert.equal(result.advisoryText, "");
});
