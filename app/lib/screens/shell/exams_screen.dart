import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../account/profile.dart';
import '../../app/app_badge.dart';
import '../../app/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import '../../auth/phone_number.dart';
import '../../claim/claim_exam.dart';
import '../../claim/claim_guide.dart';
import '../../claim/exam_repository.dart';
import '../../claim/questionnaire_repository.dart';
import '../../forms/form_actions.dart';
import '../../forms/iso_date_field.dart';
import '../../forms/repeatable_entries.dart';
import '../../forms/text_input_chain.dart';
import 'shell_pages.dart';

class ExamsScreen extends ConsumerWidget {
  const ExamsScreen({super.key, required this.caseId, this.adding = false});

  final String caseId;
  final bool adding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref.watch(claimExamsProvider(caseId));
    return ShellPage(
      title: 'C&P Prep',
      child: exams.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('These exams could not be opened.'),
        data: (saved) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EarlierClaimNote(caseId: caseId),
              const Text(
                'Add the exam after the VA schedules it. This does not schedule one.',
              ),
              const SizedBox(height: 12),
              const AppBadge.notFiled(),
              const SizedBox(height: 12),
              const _VaExamLink(),
              const SizedBox(height: 16),
              RepeatableEntries(
                entries: [
                  for (final exam in saved)
                    _ExamCard(caseId: caseId, exam: exam),
                ],
                form: _ExamForm(caseId: caseId),
                addingAnother: adding,
                onAddAnother: () => context.go(AuthRoutes.caseExamNew(caseId)),
                onCancel: () => context.go(AuthRoutes.caseExams(caseId)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ExamDetailsScreen extends ConsumerWidget {
  const ExamDetailsScreen({
    super.key,
    required this.caseId,
    required this.examId,
  });

  final String caseId;
  final String examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ExamLookup(
      caseId: caseId,
      examId: examId,
      title: 'Exam',
      builder: (exam) => _ExamForm(caseId: caseId, exam: exam),
    );
  }
}

class ExamPrepScreen extends ConsumerWidget {
  const ExamPrepScreen({super.key, required this.caseId, required this.examId});

  final String caseId;
  final String examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(questionnaireSessionProvider);
    return _ExamLookup(
      caseId: caseId,
      examId: examId,
      title: 'Prepare',
      builder: (exam) {
        final lines = session.maybeWhen(
          data: examPrepLines,
          orElse: () => const <ExamPrepLine>[],
        );
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(exam.examType, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${exam.examDate} at ${exam.examTime}'),
            const SizedBox(height: 12),
            const Text(
              'These are answers you already gave. Nothing here is new, and nothing is filed with the VA.',
            ),
            const SizedBox(height: 12),
            const _VaExamLink(),
            const SizedBox(height: 16),
            if (lines.isEmpty)
              const Text('No answers are saved yet.')
            else
              for (final line in lines) ...[
                Text(line.prompt, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(line.answer),
                const SizedBox(height: 16),
              ],
            FormActions(
              onBack: () => context.go(AuthRoutes.caseExam(caseId, exam.id)),
            ),
          ],
        );
      },
    );
  }
}

class ExamTravelScreen extends ConsumerWidget {
  const ExamTravelScreen({
    super.key,
    required this.caseId,
    required this.examId,
  });

  final String caseId;
  final String examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ExamLookup(
      caseId: caseId,
      examId: examId,
      title: 'Travel',
      builder: (exam) {
        final guidance = examTravelGuidance(exam.providerType);
        final showVaLink = exam.providerType != 'contractor';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              examProviderTypes[exam.providerType] ?? 'Not sure',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final paragraph in guidance) ...[
              Text(paragraph),
              const SizedBox(height: 12),
            ],
            if (exam.providerType != 'va') ...[
              Text(
                exam.phone.isEmpty
                    ? 'No phone number is saved for this exam.'
                    : 'The phone number saved for this exam is ${formatUsPhone(exam.phone)}.',
              ),
              const SizedBox(height: 12),
            ],
            if (showVaLink)
              const Align(
                alignment: Alignment.centerLeft,
                child: _VaExamLink(travel: true),
              ),
            FormActions(
              onBack: () => context.go(AuthRoutes.caseExam(caseId, exam.id)),
            ),
          ],
        );
      },
    );
  }
}

class _ExamLookup extends ConsumerWidget {
  const _ExamLookup({
    required this.caseId,
    required this.examId,
    required this.title,
    required this.builder,
  });

  final String caseId;
  final String examId;
  final String title;
  final Widget Function(ClaimExam exam) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref.watch(claimExamsProvider(caseId));
    return ShellPage(
      title: title,
      child: exams.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('This exam could not be opened.'),
        data: (saved) {
          final matches = [
            for (final exam in saved)
              if (exam.id == examId) exam,
          ];
          if (matches.isEmpty) {
            return const Text('This exam is not on this claim.');
          }
          return builder(matches.first);
        },
      ),
    );
  }
}

class _ExamCard extends ConsumerWidget {
  const _ExamCard({required this.caseId, required this.exam});

  final String caseId;
  final ClaimExam exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.go(AuthRoutes.caseExam(caseId, exam.id)),
      child: EntryCard(
        onRemove: () => _archive(context, ref),
        fields: [
          EntryField(label: 'Exam date', value: exam.examDate),
          EntryField(label: 'Time', value: exam.examTime),
          EntryField(
            label: 'Time zone',
            value: profileTimezones[exam.timezone] ?? exam.timezone,
          ),
          EntryField(label: 'Exam type or conditions', value: exam.examType),
          EntryField(
            label: 'Who is giving the exam',
            value: examProviderTypes[exam.providerType] ?? '',
          ),
          EntryField(label: 'Provider name', value: exam.providerName),
          EntryField(label: 'Location', value: exam.location),
        ],
      ),
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    try {
      await ref.read(examRepositoryProvider).archive(uid: uid, examId: exam.id);
    } on ClaimGuideFailure catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _ExamForm extends ConsumerStatefulWidget {
  const _ExamForm({required this.caseId, this.exam});

  final String caseId;
  final ClaimExam? exam;

  @override
  ConsumerState<_ExamForm> createState() => _ExamFormState();
}

class _ExamFormState extends ConsumerState<_ExamForm> {
  late final TextEditingController _date;
  late final TextEditingController _time;
  late final TextEditingController _type;
  late final TextEditingController _providerName;
  late final TextEditingController _location;
  late final TextEditingController _phone;
  late final TextEditingController _notes;
  late String _timezone;
  late String _providerType;
  late bool _telehealth;
  var _busy = false;
  var _saved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final exam = widget.exam;
    _date = TextEditingController(text: exam?.examDate ?? '');
    _time = TextEditingController(text: exam?.examTime ?? '');
    _type = TextEditingController(text: exam?.examType ?? '');
    _providerName = TextEditingController(text: exam?.providerName ?? '');
    _location = TextEditingController(text: exam?.location ?? '');
    _phone = TextEditingController(text: exam?.phone ?? '');
    _notes = TextEditingController(text: exam?.notes ?? '');
    _timezone = exam?.timezone ?? defaultProfileTimezone;
    _providerType = exam?.providerType ?? 'unknown';
    _telehealth = exam?.telehealth ?? false;
  }

  @override
  void dispose() {
    _date.dispose();
    _time.dispose();
    _type.dispose();
    _providerName.dispose();
    _location.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.exam != null;
    return TextInputChain(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IsoDateField(controller: _date, label: 'Exam date', enabled: !_busy),
          const SizedBox(height: 12),
          TimeField(controller: _time, label: 'Time', enabled: !_busy),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('zone-$_timezone'),
            initialValue: _timezone,
            decoration: const InputDecoration(labelText: 'Time zone'),
            items: [
              for (final entry in profileTimezones.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _timezone = value;
                      _saved = false;
                    });
                  },
          ),
          const SizedBox(height: 12),
          ChainTextField(
            controller: _type,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            maxLength: examTypeMax,
            decoration: const InputDecoration(
              labelText: 'Exam type or conditions',
            ),
            onChanged: (_) => setState(() => _saved = false),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('provider-$_providerType'),
            initialValue: _providerType,
            decoration: const InputDecoration(
              labelText: 'Who is giving the exam',
            ),
            items: [
              for (final entry in examProviderTypes.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _providerType = value;
                      _saved = false;
                    });
                  },
          ),
          const SizedBox(height: 12),
          ChainTextField(
            controller: _providerName,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            maxLength: examProviderNameMax,
            decoration: const InputDecoration(labelText: 'Provider name'),
            onChanged: (_) => setState(() => _saved = false),
          ),
          const SizedBox(height: 12),
          ChainTextField(
            controller: _location,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            maxLength: examLocationMax,
            decoration: const InputDecoration(labelText: 'Location'),
            onChanged: (_) => setState(() => _saved = false),
          ),
          const SizedBox(height: 12),
          MobileNumberField(controller: _phone, enabled: !_busy),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _telehealth,
            onChanged: _busy
                ? null
                : (value) => setState(() {
                    _telehealth = value ?? false;
                    _saved = false;
                  }),
            title: const Text('This exam is telehealth'),
          ),
          ChainTextField(
            controller: _notes,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 6,
            maxLength: examNotesMax,
            decoration: const InputDecoration(labelText: 'Notes'),
            onChanged: (_) => setState(() => _saved = false),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_saved) ...[
            const SizedBox(height: 12),
            Text(
              'Saved.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (editing) ...[
            FormActions(
              onBack: _busy
                  ? null
                  : () => context.go(AuthRoutes.caseExams(widget.caseId)),
              onPrimary: _busy ? null : _save,
              primaryLabel: 'Save',
              busy: _busy,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => context.go(
                        AuthRoutes.caseExamPrep(widget.caseId, widget.exam!.id),
                      ),
                child: const Text('Prepare'),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => context.go(
                        AuthRoutes.caseExamTravel(
                          widget.caseId,
                          widget.exam!.id,
                        ),
                      ),
                child: const Text('Travel'),
              ),
            ),
            const SizedBox(height: 8),
            const _VaExamLink(),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                style: dangerTextStyle(),
                onPressed: _busy ? null : _archive,
                child: const Text('Remove'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            FilledButton(
              style: secondaryFilledStyle(),
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Add this exam'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    final error = examDraftError(
      examDate: _date.text,
      examTime: _time.text,
      timezone: _timezone,
      examType: _type.text,
      providerType: _providerType,
      providerName: _providerName.text,
      location: _location.text,
      phone: _phone.text,
      notes: _notes.text,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repository = ref.read(examRepositoryProvider);
    try {
      final exam = widget.exam;
      if (exam == null) {
        await repository.add(
          uid: uid,
          caseId: widget.caseId,
          examDate: _date.text,
          examTime: _time.text,
          timezone: _timezone,
          examType: _type.text,
          providerType: _providerType,
          providerName: _providerName.text,
          location: _location.text,
          phone: _phone.text,
          telehealth: _telehealth,
          notes: _notes.text,
        );
        if (!mounted) return;
        context.go(AuthRoutes.caseExams(widget.caseId));
        return;
      }
      await repository.update(
        uid: uid,
        examId: exam.id,
        caseId: widget.caseId,
        examDate: _date.text,
        examTime: _time.text,
        timezone: _timezone,
        examType: _type.text,
        providerType: _providerType,
        providerName: _providerName.text,
        location: _location.text,
        phone: _phone.text,
        telehealth: _telehealth,
        notes: _notes.text,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _saved = true;
      });
    } on ClaimGuideFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'That exam could not be saved. Try again.';
      });
    }
  }

  Future<void> _archive() async {
    final exam = widget.exam;
    final uid = ref.read(authControllerProvider).session?.uid;
    if (exam == null || uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(examRepositoryProvider).archive(uid: uid, examId: exam.id);
      if (!mounted) return;
      context.go(AuthRoutes.caseExams(widget.caseId));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'That exam could not be removed. Try again.';
      });
    }
  }
}

class _VaExamLink extends StatelessWidget {
  const _VaExamLink({this.travel = false});

  final bool travel;

  @override
  Widget build(BuildContext context) {
    final label = travel ? 'VA travel pay' : 'VA claim exam page';
    final url = travel ? vaTravelPayUrl : vaClaimExamUrl;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () async {
          final opened = await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
          if (opened || !context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That page could not be opened.')),
          );
        },
        child: Text(label),
      ),
    );
  }
}
