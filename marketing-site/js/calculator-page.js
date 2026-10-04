(function () {
  var ratings = [];
  var next = 10;
  var calc = window.VcbCalculator;
  var list = document.querySelector("#rating-list");
  var select = document.querySelector("#rating-select");
  var spouse = document.querySelector("#spouse");
  var spouseAid = document.querySelector("#spouse-aid");
  var parents = document.querySelector("#parents");
  var under = document.querySelector("#children-under");
  var school = document.querySelector("#children-school");

  function count(input) {
    var value = Number(input.value);
    if (!Number.isFinite(value) || value < 0) return 0;
    return Math.floor(value);
  }

  function render() {
    list.replaceChildren();
    if (ratings.length === 0) {
      var empty = document.createElement("p");
      empty.textContent = "Add a rating to see a combined result.";
      list.append(empty);
    }
    ratings.forEach(function (rating, index) {
      var row = document.createElement("div");
      row.className = "rating-row";
      var name = document.createElement("span");
      name.textContent = rating + "%";
      var remove = document.createElement("button");
      remove.type = "button";
      remove.textContent = "Remove";
      remove.addEventListener("click", function () {
        ratings.splice(index, 1);
        render();
      });
      row.append(name, remove);
      list.append(row);
    });

    var unrounded = calc.unroundedCombinedRating(ratings);
    var rounded = calc.roundedCombinedRating(unrounded);
    document.querySelector("#combined-value").textContent = ratings.length
      ? "Combined value " + unrounded
      : "";
    document.querySelector("#rounded-rating").textContent = ratings.length
      ? "Rounded rating " + rounded + "%"
      : "";

    spouseAid.disabled = !spouse.checked;
    if (!spouse.checked) spouseAid.checked = false;
    var options = {
      spouse: spouse.checked,
      spouseAid: spouseAid.checked,
      parents: Number(parents.value),
      childrenUnder18: count(under),
      childrenSchool: count(school),
    };
    var cents = ratings.length ? calc.monthlyCents(rounded, options) : null;
    var monthly = document.querySelector("#monthly");
    var note = document.querySelector("#dependent-note");
    if (cents == null) {
      monthly.textContent = "";
      note.hidden = true;
      return;
    }
    monthly.textContent = "Estimated monthly payment " + calc.formatDollars(cents);
    note.hidden = rounded !== 10 && rounded !== 20;
  }

  document.querySelector("#add-rating").addEventListener("click", function () {
    ratings.push(next);
    render();
  });
  select.addEventListener("change", function () { next = Number(select.value); });
  [spouse, spouseAid, parents, under, school].forEach(function (field) {
    field.addEventListener("change", render);
    field.addEventListener("input", render);
  });
  render();
})();
