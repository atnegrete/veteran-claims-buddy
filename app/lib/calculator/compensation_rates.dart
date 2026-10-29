/// VA monthly disability compensation, effective December 1, 2025.
///
/// This mirrors `marketing-site/js/calculator.js` so the app and the public
/// calculator agree. Amounts are whole cents. Source: VA compensation rates,
/// https://www.va.gov/disability/compensation-rates/veteran-rates/,
/// retrieved 2026-10-04.
library;

import 'package:intl/intl.dart';

/// The 10% and 20% rates, which never increase for dependents.
const _alone = <int, int>{10: 18042, 20: 35666};

/// Base monthly cents keyed `spouse-parents-child`, where `child` is 1 when at
/// least one dependent child is present. Extra children add from the tables
/// below. Spouse is 0 or 1, parents 0 to 2.
const _basic = <String, Map<int, int>>{
  '0-0-0': {
    30: 55247,
    40: 79584,
    50: 113290,
    60: 143502,
    70: 180845,
    80: 210215,
    90: 236230,
    100: 393858,
  },
  '1-0-0': {
    30: 61747,
    40: 88284,
    50: 124190,
    60: 156602,
    70: 196145,
    80: 227715,
    90: 255930,
    100: 415817,
  },
  '1-1-0': {
    30: 66947,
    40: 95284,
    50: 132990,
    60: 167102,
    70: 208445,
    80: 241715,
    90: 271730,
    100: 433441,
  },
  '1-2-0': {
    30: 72147,
    40: 102284,
    50: 141790,
    60: 177602,
    70: 220745,
    80: 255715,
    90: 287530,
    100: 451065,
  },
  '0-1-0': {
    30: 60447,
    40: 86584,
    50: 122090,
    60: 154002,
    70: 193145,
    80: 224215,
    90: 252030,
    100: 411482,
  },
  '0-2-0': {
    30: 65647,
    40: 93584,
    50: 130890,
    60: 164502,
    70: 205445,
    80: 238215,
    90: 267830,
    100: 429106,
  },
  '0-0-1': {
    30: 59647,
    40: 85384,
    50: 120590,
    60: 152302,
    70: 191045,
    80: 221915,
    90: 249430,
    100: 408543,
  },
  '1-0-1': {
    30: 66647,
    40: 94784,
    50: 132290,
    60: 166302,
    70: 207445,
    80: 240615,
    90: 270430,
    100: 431899,
  },
  '1-1-1': {
    30: 71847,
    40: 101784,
    50: 141090,
    60: 176802,
    70: 219745,
    80: 254615,
    90: 286230,
    100: 449523,
  },
  '1-2-1': {
    30: 77047,
    40: 108784,
    50: 149890,
    60: 187302,
    70: 232045,
    80: 268615,
    90: 302030,
    100: 467147,
  },
  '0-1-1': {
    30: 64847,
    40: 92384,
    50: 129390,
    60: 162802,
    70: 203345,
    80: 235915,
    90: 265230,
    100: 426167,
  },
  '0-2-1': {
    30: 70047,
    40: 99384,
    50: 138190,
    60: 173302,
    70: 215645,
    80: 249915,
    90: 281030,
    100: 443791,
  },
};

/// Added monthly cents for each dependent child under 18 beyond the first.
const _extraUnder = <int, int>{
  30: 3200,
  40: 4300,
  50: 5400,
  60: 6500,
  70: 7600,
  80: 8700,
  90: 9800,
  100: 10911,
};

/// Added monthly cents for each child 18+ in a qualifying school program.
const _extraSchool = <int, int>{
  30: 10500,
  40: 14000,
  50: 17600,
  60: 21100,
  70: 24600,
  80: 28100,
  90: 31700,
  100: 35245,
};

/// Added monthly cents when a spouse receives Aid and Attendance.
const _spouseAid = <int, int>{
  30: 6100,
  40: 8100,
  50: 10100,
  60: 12100,
  70: 14100,
  80: 16100,
  90: 18100,
  100: 20141,
};

/// The dependent situation that sets the monthly rate.
class CompensationInput {
  const CompensationInput({
    this.spouse = false,
    this.spouseAid = false,
    this.parents = 0,
    this.childrenUnder18 = 0,
    this.childrenSchool = 0,
  });

  final bool spouse;
  final bool spouseAid;
  final int parents;
  final int childrenUnder18;
  final int childrenSchool;
}

/// Monthly compensation in whole cents for a rounded rating, or `null` when the
/// rating is below 10 or otherwise has no published rate.
int? monthlyCompensationCents(int rounded, CompensationInput input) {
  if (!_basic['0-0-0']!.containsKey(rounded) && !_alone.containsKey(rounded)) {
    return null;
  }
  if (rounded == 10 || rounded == 20) return _alone[rounded];

  final spouse = input.spouse ? 1 : 0;
  final parents = input.parents.clamp(0, 2);
  final under = input.childrenUnder18 < 0 ? 0 : input.childrenUnder18;
  final school = input.childrenSchool < 0 ? 0 : input.childrenSchool;
  final child = (under + school) > 0 ? 1 : 0;

  var cents = _basic['$spouse-$parents-$child']![rounded]!;
  var extraUnderCount = under;
  var extraSchoolCount = school;
  if (child == 1) {
    if (under > 0) {
      extraUnderCount = under - 1;
    } else {
      extraSchoolCount = school - 1;
    }
  }
  cents += extraUnderCount * _extraUnder[rounded]!;
  cents += extraSchoolCount * _extraSchool[rounded]!;
  if (spouse == 1 && input.spouseAid) cents += _spouseAid[rounded]!;
  return cents;
}

final _dollars = NumberFormat('#,##0', 'en_US');

/// Formats whole cents as a US dollar string, for example `$3,946.25`.
String formatDollars(int cents) {
  final sign = cents < 0 ? '-' : '';
  final absolute = cents.abs();
  final whole = absolute ~/ 100;
  final remainder = (absolute % 100).toString().padLeft(2, '0');
  return '$sign\$${_dollars.format(whole)}.$remainder';
}
