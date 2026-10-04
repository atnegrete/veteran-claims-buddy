import 'discovery_questions.dart';

class CatalogChoice {
  const CatalogChoice({
    required this.value,
    required this.label,
    this.crisisNotice,
  });

  final String value;
  final String label;
  final String? crisisNotice;
}

class CatalogRule {
  const CatalogRule({
    required this.questionId,
    this.equals,
    this.includes,
    this.includesAny,
  });

  final String questionId;
  final String? equals;
  final String? includes;

  /// Matches when the answer contains any one of these values.
  final List<String>? includesAny;
}

class CatalogQuestion {
  const CatalogQuestion({
    required this.id,
    required this.prompt,
    required this.answerType,
    required this.order,
    this.options = const [],
    this.required = true,
    this.section = '',
    this.showWhen = const [],
    this.createsCondition,
    this.createsEachOption = false,
    this.createsExcept = const ['none', 'not_sure', 'not_applicable'],
    this.includeInIntake = true,
  });

  final String id;
  final String prompt;
  final String answerType;
  final int order;
  final List<CatalogChoice> options;
  final bool required;
  final String section;
  final List<CatalogRule> showWhen;
  final String? createsCondition;
  final bool createsEachOption;
  final List<String> createsExcept;
  final bool includeInIntake;

  bool get isMulti => answerType == 'multiChoice';
  bool get isYearMonth => answerType == 'yearMonth';
  bool get isNote => answerType == 'note';
}

class QuestionnaireSession {
  const QuestionnaireSession({required this.answers, required this.questions});

  final Map<String, List<String>> answers;
  final List<CatalogQuestion> questions;

  static const empty = QuestionnaireSession(answers: {}, questions: []);
}

const catalogDefinitionId = 'condition-discovery-v2';

const widgetPreviewCatalog = <CatalogQuestion>[
  CatalogQuestion(
    id: 'head',
    prompt: 'Do you have recurring headaches, dizziness, or other problems with your head or nerves?',
    answerType: 'singleChoice',
    section: 'gates',
    order: 0,
    options: [
      CatalogChoice(value: 'yes', label: 'Yes'),
      CatalogChoice(value: 'no', label: 'No'),
    ],
  ),
  CatalogQuestion(
    id: 'eyes',
    prompt: 'Do you have trouble with your eyes or vision?',
    answerType: 'singleChoice',
    section: 'gates',
    order: 1,
    options: [
      CatalogChoice(value: 'yes', label: 'Yes'),
      CatalogChoice(value: 'no', label: 'No'),
    ],
  ),
];

CatalogQuestion? catalogQuestionById(
  List<CatalogQuestion> questions,
  String id,
) {
  for (final question in questions) {
    if (question.id == id) return question;
  }
  return null;
}

List<String> catalogValues(Object? raw) {
  if (raw is String && raw.isNotEmpty) return [raw];
  if (raw is List) {
    return [
      for (final item in raw)
        if (item is String && item.isNotEmpty) item,
    ];
  }
  return const [];
}

bool catalogRuleMatches(CatalogRule rule, Map<String, List<String>> answers) {
  final values = answers[rule.questionId] ?? const <String>[];
  final equals = rule.equals;
  if (equals != null && !values.contains(equals)) return false;
  final includes = rule.includes;
  if (includes != null && !values.contains(includes)) return false;
  final includesAny = rule.includesAny;
  if (includesAny != null &&
      includesAny.isNotEmpty &&
      !includesAny.any(values.contains)) {
    return false;
  }
  return true;
}

bool catalogQuestionVisible(
  CatalogQuestion question,
  Map<String, List<String>> answers,
) {
  if (!question.includeInIntake) return false;
  for (final rule in question.showWhen) {
    if (!catalogRuleMatches(rule, answers)) return false;
  }
  return true;
}

Map<String, List<String>> activeCatalogAnswers(
  List<CatalogQuestion> questions,
  Map<String, List<String>> raw,
) {
  final active = {
    for (final entry in raw.entries) entry.key: List<String>.from(entry.value),
  };
  var changed = true;
  while (changed) {
    changed = false;
    for (final question in questions) {
      if (!catalogQuestionVisible(question, active) &&
          active.containsKey(question.id)) {
        active.remove(question.id);
        changed = true;
      }
    }
  }
  return active;
}

List<CatalogQuestion> visibleCatalogQuestions(
  List<CatalogQuestion> questions,
  Map<String, List<String>> answers,
) {
  final active = activeCatalogAnswers(questions, answers);
  final ordered = [...questions]..sort((a, b) => a.order.compareTo(b.order));
  return [
    for (final question in ordered)
      if (catalogQuestionVisible(question, active)) question,
  ];
}

Map<String, List<String>> applyCatalogAnswer(
  List<CatalogQuestion> questions,
  Map<String, List<String>> answers,
  String questionId,
  List<String> values,
) {
  final next = {
    for (final entry in answers.entries)
      entry.key: List<String>.from(entry.value),
  };
  if (values.isEmpty) {
    next.remove(questionId);
  } else {
    next[questionId] = List<String>.from(values);
  }
  return activeCatalogAnswers(questions, next);
}

bool catalogAnswered(
  CatalogQuestion question,
  Map<String, List<String>> answers,
) {
  final values = answers[question.id];
  return values != null && values.isNotEmpty;
}

class CatalogPage {
  const CatalogPage({
    required this.id,
    required this.title,
    required this.questions,
  });

  final String id;
  final String title;
  final List<CatalogQuestion> questions;
}

const catalogSectionTitles = <String, String>{
  'gates': 'Where should we look?',
  'heart': 'Heart and circulation',
  'head': 'Head and nerves',
  'eyes': 'Eyes',
  'hearing': 'Hearing and ears',
  'ent': 'Nose, sinus, and throat',
  'respiratory': 'Breathing',
  'sleep': 'Sleep',
  'gi': 'Stomach and bowel',
  'gu': 'Kidney and urinary',
  'endocrine': 'Hormones',
  'skin': 'Skin',
  'back': 'Back',
  'neck': 'Neck',
  'joints': 'Joints, muscles, and bones',
  'nerves': 'Nerves',
  'mental': 'Mental health',
  'dental': 'Jaw and mouth',
  'reproductive': 'Reproductive',
  'blood': 'Blood and infection',
  'general': 'Whole body',
};

/// The opening page is only the yes/no gates. A later question never joins
/// that page, even when its saved section is blank.
String catalogPageId(
  CatalogQuestion question,
  Map<String, CatalogQuestion> byId,
  Map<String, String> gateTopic,
) {
  if (question.section == 'gates') return 'gates';
  if (question.section.isNotEmpty) return question.section;
  return _topicPageId(question, byId, gateTopic, <String>{});
}

String _topicPageId(
  CatalogQuestion question,
  Map<String, CatalogQuestion> byId,
  Map<String, String> gateTopic,
  Set<String> seen,
) {
  if (!seen.add(question.id)) {
    final dot = question.id.indexOf('.');
    return dot > 0 ? question.id.substring(0, dot) : question.id;
  }
  for (final rule in question.showWhen) {
    final parent = byId[rule.questionId];
    if (parent == null) continue;
    if (parent.section.isNotEmpty && parent.section != 'gates') {
      return parent.section;
    }
    if (parent.section == 'gates') {
      return gateTopic[parent.id] ?? parent.id;
    }
    final inherited = _topicPageId(parent, byId, gateTopic, seen);
    if (inherited != 'gates') return inherited;
  }
  final dot = question.id.indexOf('.');
  return dot > 0 ? question.id.substring(0, dot) : question.id;
}

Map<String, String> _gateTopics(List<CatalogQuestion> questions) {
  final byId = {for (final question in questions) question.id: question};
  final topics = <String, String>{};
  for (final question in questions) {
    if (question.section.isEmpty || question.section == 'gates') continue;
    for (final rule in question.showWhen) {
      if (rule.equals != 'yes') continue;
      final parent = byId[rule.questionId];
      if (parent != null && parent.section == 'gates') {
        topics.putIfAbsent(parent.id, () => question.section);
      }
    }
  }
  return topics;
}

/// Every intake question on a topic page, including ones that do not apply yet.
List<CatalogQuestion> catalogTopicQuestions(
  List<CatalogQuestion> questions,
  String pageId,
) {
  final byId = {for (final question in questions) question.id: question};
  final topics = _gateTopics(questions);
  final ordered = [...questions]..sort((a, b) => a.order.compareTo(b.order));
  return [
    for (final question in ordered)
      if (question.includeInIntake &&
          catalogPageId(question, byId, topics) == pageId)
        question,
  ];
}

/// Why a question is off, naming each answer that does not match.
String? catalogBlockedLabel(
  CatalogQuestion question,
  List<CatalogQuestion> questions,
  Map<String, List<String>> answers,
) {
  if (catalogQuestionVisible(question, answers)) return null;
  final byId = {for (final item in questions) item.id: item};
  final prompts = <String>[
    for (final rule in question.showWhen)
      if (!catalogRuleMatches(rule, answers))
        byId[rule.questionId]?.prompt ?? rule.questionId,
  ];
  if (prompts.isEmpty) return 'Does not apply.';
  if (prompts.length == 1) {
    return 'Does not apply based on your answer to ${prompts.single}';
  }
  final last = prompts.removeLast();
  return 'Does not apply based on your answers to ${prompts.join(', ')} and $last';
}

List<CatalogPage> catalogPages(
  List<CatalogQuestion> questions,
  Map<String, List<String>> answers,
) {
  final byId = {for (final question in questions) question.id: question};
  final topics = _gateTopics(questions);
  final grouped = <String, List<CatalogQuestion>>{};
  for (final question in visibleCatalogQuestions(questions, answers)) {
    grouped
        .putIfAbsent(catalogPageId(question, byId, topics), () => [])
        .add(question);
  }
  return [
    for (final entry in grouped.entries)
      CatalogPage(
        id: entry.key,
        title: catalogSectionTitles[entry.key] ?? entry.key,
        questions: entry.value,
      ),
  ];
}

/// The topic page for the question that created this condition.
String? catalogPageIdForCondition(
  List<CatalogQuestion> questions,
  String conditionId,
) {
  final split = conditionId.split('__');
  final questionId = split.isEmpty ? conditionId : split.first;
  final question = catalogQuestionById(questions, questionId);
  if (question == null) return null;
  final byId = {for (final item in questions) item.id: item};
  return catalogPageId(question, byId, _gateTopics(questions));
}

/// The first page that still has a question without an answer.
String? resumeCatalogPageId(
  List<CatalogQuestion> questions,
  Map<String, List<String>> answers,
) {
  for (final page in catalogPages(questions, answers)) {
    for (final question in page.questions) {
      if (!catalogAnswered(question, answers)) return page.id;
    }
  }
  return null;
}

class AnswerDiff {
  const AnswerDiff({required this.changed, required this.removed});

  final Map<String, List<String>> changed;
  final Set<String> removed;

  bool get isEmpty => changed.isEmpty && removed.isEmpty;
}

bool sameAnswerValues(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

AnswerDiff diffAnswers(
  Map<String, List<String>> previous,
  Map<String, List<String>> next,
) {
  final changed = <String, List<String>>{};
  final removed = <String>{};
  for (final entry in next.entries) {
    final prior = previous[entry.key];
    if (prior == null || !sameAnswerValues(prior, entry.value)) {
      changed[entry.key] = List<String>.from(entry.value);
    }
  }
  for (final key in previous.keys) {
    if (!next.containsKey(key)) removed.add(key);
  }
  return AnswerDiff(changed: changed, removed: removed);
}

String? nextCatalogQuestionId(
  List<CatalogQuestion> questions,
  Map<String, List<String>> answers,
  String questionId,
) {
  final visible = visibleCatalogQuestions(questions, answers);
  final index = visible.indexWhere((question) => question.id == questionId);
  if (index < 0 || index + 1 >= visible.length) return null;
  return visible[index + 1].id;
}

String? previousCatalogQuestionId(
  List<CatalogQuestion> questions,
  Map<String, List<String>> answers,
  String questionId,
) {
  final visible = visibleCatalogQuestions(questions, answers);
  final index = visible.indexWhere((question) => question.id == questionId);
  if (index <= 0) return null;
  return visible[index - 1].id;
}

String? resumeCatalogQuestionId(
  List<CatalogQuestion> questions,
  Map<String, List<String>> answers,
) {
  final active = activeCatalogAnswers(questions, answers);
  for (final question in visibleCatalogQuestions(questions, active)) {
    if (!active.containsKey(question.id)) return question.id;
  }
  return null;
}

bool catalogAnswerCreatesCrisis(CatalogQuestion question, List<String> values) {
  for (final choice in question.options) {
    if (choice.crisisNotice != null && values.contains(choice.value)) {
      return true;
    }
  }
  return false;
}

String catalogDisplayValue(CatalogQuestion question, List<String> values) {
  if (values.length == 1 && values.first == 'skipped') return 'Skipped';
  final labels = <String>[];
  for (final value in values) {
    var label = value;
    for (final choice in question.options) {
      if (choice.value == value) label = choice.label;
    }
    labels.add(label);
  }
  return labels.join(', ');
}

String bodySystemForSection(String section) {
  return switch (section) {
    'eyes' => 'eyes',
    'hearing' => 'hearing',
    'ent' => 'ent',
    'respiratory' => 'respiratory',
    'sleep' => 'sleep',
    'heart' => 'cardiovascular',
    'gi' => 'gastrointestinal',
    'gu' => 'genitourinary',
    'endocrine' => 'endocrine',
    'skin' => 'skin',
    'back' || 'neck' || 'joints' => 'musculoskeletal',
    'nerves' => 'peripheralNerves',
    'mental' => 'mentalHealth',
    'dental' => 'dental',
    'reproductive' => 'reproductive',
    'head' || 'gates' => 'neurological',
    _ => 'other',
  };
}

List<DiscoveryCondition> catalogConditions(
  List<CatalogQuestion> questions,
  Map<String, List<String>> answers,
) {
  final active = activeCatalogAnswers(questions, answers);
  final found = <DiscoveryCondition>[];
  for (final question in visibleCatalogQuestions(questions, active)) {
    final values = active[question.id] ?? const <String>[];
    if (question.createsCondition != null && values.contains('yes')) {
      found.add(
        DiscoveryCondition(id: question.id, name: question.createsCondition!),
      );
    }
    if (!question.createsEachOption) continue;
    for (final choice in question.options) {
      if (question.createsExcept.contains(choice.value)) continue;
      if (!values.contains(choice.value)) continue;
      found.add(
        DiscoveryCondition(
          id: '${question.id}__${choice.value}',
          name: choice.label,
        ),
      );
    }
  }
  return found;
}

Set<String> catalogConditionIds(List<CatalogQuestion> questions) {
  final ids = <String>{};
  for (final question in questions) {
    if (!question.includeInIntake) continue;
    if (question.createsCondition != null) ids.add(question.id);
    if (!question.createsEachOption) continue;
    for (final choice in question.options) {
      if (question.createsExcept.contains(choice.value)) continue;
      ids.add('${question.id}__${choice.value}');
    }
  }
  return ids;
}

CatalogQuestion catalogQuestionFromMap(Map<String, dynamic> data, String id) {
  final options = <CatalogChoice>[];
  final rawOptions = data['options'];
  if (rawOptions is List) {
    for (final item in rawOptions) {
      if (item is! Map) continue;
      final value = item['value'];
      final label = item['label'];
      if (value is! String || label is! String) continue;
      final crisis = item['crisisNotice'];
      options.add(
        CatalogChoice(
          value: value,
          label: label,
          crisisNotice: crisis is String ? crisis : null,
        ),
      );
    }
  }
  final rules = <CatalogRule>[];
  final rawRules = data['showWhen'];
  if (rawRules is List) {
    for (final item in rawRules) {
      if (item is! Map) continue;
      final questionId = item['questionId'];
      if (questionId is! String) continue;
      final equals = item['equals'];
      final includes = item['includes'];
      final rawAny = item['includesAny'];
      final includesAny = rawAny is List
          ? [
              for (final value in rawAny)
                if (value is String && value.isNotEmpty) value,
            ]
          : null;
      rules.add(
        CatalogRule(
          questionId: questionId,
          equals: equals is String ? equals : null,
          includes: includes is String ? includes : null,
          includesAny: includesAny == null || includesAny.isEmpty
              ? null
              : includesAny,
        ),
      );
    }
  }
  final except = <String>[];
  final rawExcept = data['createsExcept'];
  if (rawExcept is List) {
    for (final item in rawExcept) {
      if (item is String) except.add(item);
    }
  }
  final order = data['order'];
  final creates = data['createsCondition'];
  return CatalogQuestion(
    id: id,
    prompt: data['prompt'] is String ? data['prompt'] as String : '',
    answerType: data['answerType'] is String
        ? data['answerType'] as String
        : 'singleChoice',
    order: order is int ? order : 0,
    options: options,
    required: data['required'] is bool ? data['required'] as bool : true,
    section: data['section'] is String ? data['section'] as String : '',
    showWhen: rules,
    createsCondition: creates is String ? creates : null,
    createsEachOption: data['createsEachOption'] == true,
    createsExcept: except.isEmpty
        ? const ['none', 'not_sure', 'not_applicable']
        : except,
    includeInIntake: data['includeInIntake'] is bool
        ? data['includeInIntake'] as bool
        : true,
  );
}

bool validYearMonth(String text) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(text);
  if (match == null) return false;
  final month = int.parse(match.group(2)!);
  return month >= 1 && month <= 12;
}
