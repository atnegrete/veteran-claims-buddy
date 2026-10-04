class DiscoveryChoice {
  const DiscoveryChoice(this.value, this.label);

  final String value;
  final String label;
}

const yesNoChoices = <DiscoveryChoice>[
  DiscoveryChoice('yes', 'Yes'),
  DiscoveryChoice('no', 'No'),
];

const sideChoices = <DiscoveryChoice>[
  DiscoveryChoice('left', 'Left'),
  DiscoveryChoice('right', 'Right'),
  DiscoveryChoice('both', 'Both'),
];

class DiscoveryQuestion {
  const DiscoveryQuestion({
    required this.id,
    required this.prompt,
    required this.bodySystem,
    this.conditionName,
    this.visibleWhenYes,
    this.updatesConditionFrom,
    this.choices = yesNoChoices,
  });

  final String id;
  final String prompt;
  final String bodySystem;
  final String? conditionName;

  /// Shown only after that question was answered yes.
  final String? visibleWhenYes;

  /// Side and similar answers rename this condition instead of creating another.
  final String? updatesConditionFrom;
  final List<DiscoveryChoice> choices;

  bool isVisible(Map<String, String> answers) {
    final parent = visibleWhenYes;
    if (parent == null) return true;
    return answers[parent] == 'yes';
  }
}

const discoveryDefinitionId = 'condition-discovery-v1';
const discoveryQuestionnaireId = 'condition-discovery';

const discoveryQuestions = <DiscoveryQuestion>[
  DiscoveryQuestion(
    id: 'head',
    prompt: 'Do you have recurring headaches, dizziness, or other head or nerve symptoms?',
    bodySystem: 'neurological',
    conditionName: 'Head or nerve symptoms',
  ),
  DiscoveryQuestion(
    id: 'eyes',
    prompt: 'Do you have trouble with your eyes or vision?',
    bodySystem: 'eyes',
    conditionName: 'Eye or vision symptoms',
  ),
  DiscoveryQuestion(
    id: 'hearing',
    prompt: 'Do you have trouble hearing, ringing in the ears, or balance problems?',
    bodySystem: 'hearing',
    conditionName: 'Hearing, ringing, or balance symptoms',
  ),
  DiscoveryQuestion(
    id: 'ent',
    prompt: 'Do you have recurring nose, sinus, or throat problems?',
    bodySystem: 'ent',
    conditionName: 'Nose, sinus, or throat symptoms',
  ),
  DiscoveryQuestion(
    id: 'respiratory',
    prompt: 'Do you have recurring breathing problems?',
    bodySystem: 'respiratory',
    conditionName: 'Breathing symptoms',
  ),
  DiscoveryQuestion(
    id: 'sleep',
    prompt: 'Do you have trouble sleeping, or does your breathing stop while you sleep?',
    bodySystem: 'sleep',
    conditionName: 'Sleep symptoms',
  ),
  DiscoveryQuestion(
    id: 'cardiovascular',
    prompt: 'Do you have recurring heart or circulation symptoms?',
    bodySystem: 'cardiovascular',
    conditionName: 'Heart or circulation symptoms',
  ),
  DiscoveryQuestion(
    id: 'gastrointestinal',
    prompt: 'Do you have recurring stomach or bowel problems?',
    bodySystem: 'gastrointestinal',
    conditionName: 'Stomach or bowel symptoms',
  ),
  DiscoveryQuestion(
    id: 'genitourinary',
    prompt: 'Do you have recurring bladder or urinary problems?',
    bodySystem: 'genitourinary',
    conditionName: 'Bladder or urinary symptoms',
  ),
  DiscoveryQuestion(
    id: 'endocrine',
    prompt: 'Do you have a thyroid, diabetes, or other hormone-related condition you want to include?',
    bodySystem: 'endocrine',
    conditionName: 'Hormone-related condition',
  ),
  DiscoveryQuestion(
    id: 'skin',
    prompt:
        'Do you have a recurring skin condition or a scar that bothers you?',
    bodySystem: 'skin',
    conditionName: 'Skin condition or scar',
  ),
  DiscoveryQuestion(
    id: 'back',
    prompt: 'Do you have recurring back pain, stiffness, or limited movement?',
    bodySystem: 'musculoskeletal',
    conditionName: 'Recurring back pain',
  ),
  DiscoveryQuestion(
    id: 'back_radiation',
    prompt: 'Does that pain travel down either leg?',
    bodySystem: 'neurological',
    conditionName: 'Pain traveling down a leg',
    visibleWhenYes: 'back',
  ),
  DiscoveryQuestion(
    id: 'back_radiation_side',
    prompt: 'Which side?',
    bodySystem: 'neurological',
    visibleWhenYes: 'back_radiation',
    updatesConditionFrom: 'back_radiation',
    choices: sideChoices,
  ),
  DiscoveryQuestion(
    id: 'nerves',
    prompt: 'Do you have numbness, tingling, or weakness in your hands, arms, feet, or legs?',
    bodySystem: 'peripheralNerves',
    conditionName: 'Numbness, tingling, or weakness',
  ),
  DiscoveryQuestion(
    id: 'mental_health',
    prompt: 'Do you have recurring anxiety, low mood, or other mental health symptoms?',
    bodySystem: 'mentalHealth',
    conditionName: 'Mental health symptoms',
  ),
  DiscoveryQuestion(
    id: 'dental',
    prompt: 'Do you have a dental or oral problem you want to include?',
    bodySystem: 'dental',
    conditionName: 'Dental or oral problem',
  ),
  DiscoveryQuestion(
    id: 'reproductive',
    prompt: 'Do you have a reproductive condition you want to include?',
    bodySystem: 'reproductive',
    conditionName: 'Reproductive condition',
  ),
  DiscoveryQuestion(
    id: 'injury',
    prompt: 'Do you have lasting problems from a surgery or injury?',
    bodySystem: 'injury',
    conditionName: 'Lasting problems from a surgery or injury',
  ),
  DiscoveryQuestion(
    id: 'other',
    prompt: 'Is there another symptom these questions did not ask about?',
    bodySystem: 'other',
    conditionName: 'Another symptom',
  ),
];

const discoveryBodySystems = <String>[
  'neurological',
  'eyes',
  'hearing',
  'ent',
  'respiratory',
  'sleep',
  'cardiovascular',
  'gastrointestinal',
  'genitourinary',
  'endocrine',
  'skin',
  'musculoskeletal',
  'peripheralNerves',
  'mentalHealth',
  'dental',
  'reproductive',
  'injury',
  'other',
];

DiscoveryQuestion? discoveryQuestionById(String id) {
  for (final question in discoveryQuestions) {
    if (question.id == id) return question;
  }
  return null;
}

/// Drops answers whose question is hidden by an earlier answer.
Map<String, String> activeDiscoveryAnswers(Map<String, String> raw) {
  final active = Map<String, String>.from(raw);
  var changed = true;
  while (changed) {
    changed = false;
    for (final question in discoveryQuestions) {
      if (!question.isVisible(active) && active.containsKey(question.id)) {
        active.remove(question.id);
        changed = true;
      }
    }
  }
  return active;
}

List<DiscoveryQuestion> visibleDiscoveryQuestions(Map<String, String> answers) {
  final active = activeDiscoveryAnswers(answers);
  return [
    for (final question in discoveryQuestions)
      if (question.isVisible(active)) question,
  ];
}

String? nextDiscoveryQuestionId(
  Map<String, String> answers,
  String questionId,
) {
  final visible = visibleDiscoveryQuestions(answers);
  final index = visible.indexWhere((question) => question.id == questionId);
  if (index < 0 || index + 1 >= visible.length) return null;
  return visible[index + 1].id;
}

/// The next unanswered question, or null when every visible question is answered.
String? resumeDiscoveryQuestionId(Map<String, String> answers) {
  final active = activeDiscoveryAnswers(answers);
  for (final question in visibleDiscoveryQuestions(active)) {
    if (!active.containsKey(question.id)) return question.id;
  }
  if (active.isEmpty) return discoveryQuestions.first.id;
  return null;
}

Map<String, String> applyDiscoveryAnswer(
  Map<String, String> answers,
  String questionId,
  String value,
) {
  final next = Map<String, String>.from(activeDiscoveryAnswers(answers));
  next[questionId] = value;
  return activeDiscoveryAnswers(next);
}

int discoveryProgressPercent(Map<String, String> answers) {
  final active = activeDiscoveryAnswers(answers);
  final visible = visibleDiscoveryQuestions(active);
  if (visible.isEmpty) return 0;
  final answered = visible
      .where((question) => active.containsKey(question.id))
      .length;
  return ((answered / visible.length) * 100).round();
}

class DiscoveryCondition {
  const DiscoveryCondition({required this.id, required this.name});

  final String id;
  final String name;
}

/// Potential conditions from yes answers. A no does not add one.
List<DiscoveryCondition> potentialDiscoveryConditions(
  Map<String, String> answers,
) {
  final active = activeDiscoveryAnswers(answers);
  final found = <DiscoveryCondition>[];
  for (final question in discoveryQuestions) {
    final name = discoveryConditionName(question.id, active);
    if (name == null) continue;
    found.add(DiscoveryCondition(id: question.id, name: name));
  }
  return found;
}

/// Names of potential conditions from yes answers. A no does not add one.
List<String> discoveryConditionNames(Map<String, String> answers) {
  return [
    for (final condition in potentialDiscoveryConditions(answers))
      condition.name,
  ];
}

String _legPainName(String? side) {
  return switch (side) {
    'left' => 'Pain traveling down the left leg',
    'right' => 'Pain traveling down the right leg',
    'both' => 'Pain traveling down both legs',
    _ => 'Pain traveling down a leg',
  };
}

String? discoveryConditionName(String questionId, Map<String, String> answers) {
  final active = activeDiscoveryAnswers(answers);
  final question = discoveryQuestionById(questionId);
  if (question == null || question.updatesConditionFrom != null) return null;
  if (active[questionId] != 'yes') return null;
  if (questionId == 'back_radiation') {
    return _legPainName(active['back_radiation_side']);
  }
  return question.conditionName;
}
