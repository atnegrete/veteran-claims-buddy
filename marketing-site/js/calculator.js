(function () {
  var alone = { 10: 18042, 20: 35666 };
  var basic = {
    "0-0-0": { 30: 55247, 40: 79584, 50: 113290, 60: 143502, 70: 180845, 80: 210215, 90: 236230, 100: 393858 },
    "1-0-0": { 30: 61747, 40: 88284, 50: 124190, 60: 156602, 70: 196145, 80: 227715, 90: 255930, 100: 415817 },
    "1-1-0": { 30: 66947, 40: 95284, 50: 132990, 60: 167102, 70: 208445, 80: 241715, 90: 271730, 100: 433441 },
    "1-2-0": { 30: 72147, 40: 102284, 50: 141790, 60: 177602, 70: 220745, 80: 255715, 90: 287530, 100: 451065 },
    "0-1-0": { 30: 60447, 40: 86584, 50: 122090, 60: 154002, 70: 193145, 80: 224215, 90: 252030, 100: 411482 },
    "0-2-0": { 30: 65647, 40: 93584, 50: 130890, 60: 164502, 70: 205445, 80: 238215, 90: 267830, 100: 429106 },
    "0-0-1": { 30: 59647, 40: 85384, 50: 120590, 60: 152302, 70: 191045, 80: 221915, 90: 249430, 100: 408543 },
    "1-0-1": { 30: 66647, 40: 94784, 50: 132290, 60: 166302, 70: 207445, 80: 240615, 90: 270430, 100: 431899 },
    "1-1-1": { 30: 71847, 40: 101784, 50: 141090, 60: 176802, 70: 219745, 80: 254615, 90: 286230, 100: 449523 },
    "1-2-1": { 30: 77047, 40: 108784, 50: 149890, 60: 187302, 70: 232045, 80: 268615, 90: 302030, 100: 467147 },
    "0-1-1": { 30: 64847, 40: 92384, 50: 129390, 60: 162802, 70: 203345, 80: 235915, 90: 265230, 100: 426167 },
    "0-2-1": { 30: 70047, 40: 99384, 50: 138190, 60: 173302, 70: 215645, 80: 249915, 90: 281030, 100: 443791 },
  };
  var extraUnder = { 30: 3200, 40: 4300, 50: 5400, 60: 6500, 70: 7600, 80: 8700, 90: 9800, 100: 10911 };
  var extraSchool = { 30: 10500, 40: 14000, 50: 17600, 60: 21100, 70: 24600, 80: 28100, 90: 31700, 100: 35245 };
  var spouseAid = { 30: 6100, 40: 8100, 50: 10100, 60: 12100, 70: 14100, 80: 16100, 90: 18100, 100: 20141 };

  function unroundedCombinedRating(ratings) {
    var sorted = ratings.filter(function (rating) { return rating > 0; }).sort(function (a, b) { return b - a; });
    var combined = 0;
    for (var i = 0; i < sorted.length; i++) {
      combined += Math.round(sorted[i] * (100 - combined) / 100);
      if (combined > 100) return 100;
    }
    return combined;
  }

  function roundedCombinedRating(unrounded) {
    if (unrounded <= 0) return 0;
    var ones = unrounded % 10;
    var base = unrounded - ones;
    var rounded = ones >= 5 ? base + 10 : base;
    return rounded > 100 ? 100 : rounded;
  }

  function monthlyCents(rounded, options) {
    if (!basic["0-0-0"][rounded] && !alone[rounded]) return null;
    if (rounded === 10 || rounded === 20) return alone[rounded];
    var spouse = options.spouse ? 1 : 0;
    var parents = Math.max(0, Math.min(2, options.parents || 0));
    var under = Math.max(0, options.childrenUnder18 || 0);
    var school = Math.max(0, options.childrenSchool || 0);
    var child = under + school > 0 ? 1 : 0;
    var cents = basic[spouse + "-" + parents + "-" + child][rounded];
    var extraUnderCount = under;
    var extraSchoolCount = school;
    if (child) {
      if (under > 0) extraUnderCount = under - 1;
      else extraSchoolCount = school - 1;
    }
    cents += extraUnderCount * extraUnder[rounded];
    cents += extraSchoolCount * extraSchool[rounded];
    if (spouse && options.spouseAid) cents += spouseAid[rounded];
    return cents;
  }

  function formatDollars(cents) {
    var sign = cents < 0 ? "-" : "";
    var absolute = Math.abs(cents);
    var dollars = Math.floor(absolute / 100);
    var remainder = String(absolute % 100).padStart(2, "0");
    return sign + "$" + dollars.toLocaleString("en-US") + "." + remainder;
  }

  var api = {
    unroundedCombinedRating: unroundedCombinedRating,
    roundedCombinedRating: roundedCombinedRating,
    monthlyCents: monthlyCents,
    formatDollars: formatDollars,
  };

  if (typeof module !== "undefined" && module.exports) module.exports = api;
  if (typeof window !== "undefined") window.VcbCalculator = api;
})();
