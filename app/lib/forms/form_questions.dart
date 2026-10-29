/// Per-form question sets (handoff 37, Step 5). For a statement form these are
/// the short, pertinent prompts the Veteran (or a witness) answers in their own
/// words; the answers, the onboarding snapshot, and the case issues are then
/// sent to `draftFormStatement` so AI drafts the statement. For a `multiple`
/// non-statement form, a single label field names each entry (provider,
/// employer). Nothing here is filed with the VA.
///
/// Every free-text max-length below was confirmed by the owner before the field
/// was added, per `.cursor/rules/form-layout.mdc`.
library;

import 'form_catalog.dart';

/// One free-text prompt on a form's question set.
class FormQuestion {
  const FormQuestion({
    required this.id,
    required this.label,
    required this.maxLength,
    this.multiline = false,
    this.hint,
  });

  final String id;
  final String label;

  /// The confirmed maximum character count. The count stays visible.
  final int maxLength;

  /// A multiline paragraph field (keeps Return) vs a single-line field.
  final bool multiline;

  final String? hint;
}

/// The editable statement draft shares this bound with the server
/// (`functions/form_statements.js` `maxStatementChars`).
const statementBodyMaxLength = 8000;

/// Each Nexus Letters interview answer shares this bound with the server
/// (`functions/nexus_shared.js` `maxAnswerChars`). Confirmed max: 2000.
const nexusAnswerMaxLength = 2000;

/// Question sets keyed by form number (or [nexusFormId]). A form absent from
/// this map has no question step.
const Map<String, List<FormQuestion>> formQuestions = {
  // 21-4138 Statement in Support of Claim (personal statement) — lay.
  '21-4138': [
    FormQuestion(
      id: 'condition_change',
      label: 'How the condition started or worsened, in your words',
      maxLength: 4000,
      multiline: true,
    ),
    FormQuestion(
      id: 'daily_impact',
      label: 'How it affects your daily life and work',
      maxLength: 4000,
      multiline: true,
    ),
  ],
  // 21-10210 Lay / Witness Statement (buddy statement) — lay.
  '21-10210': [
    FormQuestion(
      id: 'witness_name',
      label: 'Witness full name',
      maxLength: 100,
    ),
    FormQuestion(
      id: 'witness_relationship',
      label: 'Witness relationship to you',
      maxLength: 60,
    ),
    FormQuestion(
      id: 'observed',
      label: 'What the witness saw or experienced',
      maxLength: 4000,
      multiline: true,
    ),
  ],
  // 21-0781 Mental-health in-service event statement — lay.
  '21-0781': [
    FormQuestion(
      id: 'event',
      label: 'Describe the in-service event(s)',
      maxLength: 4000,
      multiline: true,
    ),
    FormQuestion(
      id: 'event_location',
      label: 'Where it happened (unit, base, location)',
      maxLength: 200,
    ),
    FormQuestion(
      id: 'since_impact',
      label: 'How it has affected you since',
      maxLength: 4000,
      multiline: true,
    ),
  ],
  // Nexus letter — unsigned doctor draft.
  nexusFormId: [
    FormQuestion(
      id: 'cause',
      label: 'Suspected in-service cause or exposure',
      maxLength: 4000,
      multiline: true,
    ),
    FormQuestion(
      id: 'diagnosis',
      label: 'Current diagnosis, as you understand it',
      maxLength: 4000,
      multiline: true,
    ),
    FormQuestion(
      id: 'treatment',
      label: 'Treatment history to include',
      maxLength: 4000,
      multiline: true,
    ),
  ],
  // 21-4142a provider details — a single label field per entry (no AI).
  '21-4142a': [
    FormQuestion(
      id: 'provider_name',
      label: 'Private provider name',
      maxLength: 120,
    ),
  ],
  // 21-4192 employer information — a single label field per entry (no AI).
  '21-4192': [
    FormQuestion(id: 'employer_name', label: 'Employer name', maxLength: 120),
  ],
};

/// The questions for one form, or an empty list when it has no question step.
List<FormQuestion> questionsFor(String formNumber) =>
    formQuestions[formNumber] ?? const [];

/// The answer id whose value labels each entry of a `multiple` form in the
/// Package list (witness, provider, employer). Null when the form has none.
const Map<String, String> labelQuestionId = {
  '21-10210': 'witness_name',
  '21-4142a': 'provider_name',
  '21-4192': 'employer_name',
};

/// Builds the short label for a package entry from its answers. Falls back to
/// the form's short title when no label field is set or answered.
String entryLabelFor(VaFormDef def, Map<String, String> answers) {
  final key = labelQuestionId[def.formNumber];
  final value = key == null ? null : answers[key]?.trim();
  if (value != null && value.isNotEmpty) return value;
  return def.shortTitle;
}
