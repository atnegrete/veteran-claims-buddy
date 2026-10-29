import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_ui.dart';
import '../../claim/claim_guide.dart';
import '../../claim/vet_buddy.dart';
import '../../claim/vet_buddy_repository.dart';
import 'buddy_screen.dart';

class VetBuddyBubble extends ConsumerWidget {
  const VetBuddyBubble({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = Theme.of(context).colorScheme.surface;
    return FloatingActionButton(
      tooltip: 'Vet Buddy',
      onPressed: caseId.isEmpty
          ? null
          : () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                backgroundColor: surface,
                builder: (sheetContext) {
                  final inset = MediaQuery.viewInsetsOf(sheetContext).bottom;
                  final available =
                      MediaQuery.sizeOf(sheetContext).height - inset;
                  return Padding(
                    padding: EdgeInsets.only(bottom: inset),
                    child: SizedBox(
                      height: available * 0.9,
                      child: SafeArea(
                        top: false,
                        child: _VetBuddySheet(
                          caseId: caseId,
                          onOpen: (route) {
                            Navigator.of(sheetContext).pop();
                            context.go(route);
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
      child: const Icon(Icons.chat_bubble_outline),
    );
  }
}

class _VetBuddySheet extends ConsumerStatefulWidget {
  const _VetBuddySheet({required this.caseId, required this.onOpen});

  final String caseId;
  final void Function(String route) onOpen;

  @override
  ConsumerState<_VetBuddySheet> createState() => _VetBuddySheetState();
}

class _VetBuddySheetState extends ConsumerState<_VetBuddySheet> {
  final _question = TextEditingController();
  var _busy = false;
  var _pending = '';
  var _seen = 0;
  var _now = DateTime.now();
  String? _error;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _question.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _question.text.trim();
    if (text.isEmpty || _busy) return;
    if (blockedChatIdentifier(text) != null) {
      setState(
        () => _error = "Don't send a Social Security number or a long account number in chat.",
      );
      return;
    }
    final current = ref.read(vetBuddyMessagesProvider(widget.caseId));
    setState(() {
      _busy = true;
      _pending = text;
      _seen = current.asData?.value.length ?? 0;
      _error = null;
    });
    try {
      await ref.read(askVetBuddyProvider)(caseId: widget.caseId, text: text);
      if (!mounted) return;
      _question.clear();
    } on ClaimGuideFailure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _pending = '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Vet Buddy could not answer. Try again.';
          _pending = '';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _endSession() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(askVetBuddyProvider)(
        caseId: widget.caseId,
        endSession: true,
      );
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Vet Buddy could not answer. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = ref.watch(vetBuddyMessagesProvider(widget.caseId));
    final chat = ref.watch(vetBuddyChatProvider(widget.caseId));
    ref.listen(vetBuddyMessagesProvider(widget.caseId), (previous, next) {
      if (_pending.isEmpty) return;
      final count = next.asData?.value.length ?? 0;
      final before = previous?.asData?.value.length ?? _seen;
      if (count > before && mounted) setState(() => _pending = '');
    });
    final session = chat.asData?.value;
    final line = session == null
        ? null
        : sessionStatusLine(session.expiresAt, _now);
    final open = session?.isOpenAt(_now) ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Vet Buddy', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Vet Buddy explains this claim. It does not change it.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (line != null) ...[
            const SizedBox(height: 8),
            Text(
              line,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (open)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                ),
                onPressed: _busy ? null : _endSession,
                child: const Text('End session'),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Text('This chat could not be opened.'),
              data: (items) {
                if (items.isEmpty && _pending.isEmpty) {
                  return Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Ask a question about this claim.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final rows = chatRows(items);
                if (_pending.isNotEmpty) {
                  rows.add(
                    ChatRow.message(
                      VetBuddyMessage(
                        id: 'pending',
                        role: 'user',
                        content: _pending,
                      ),
                    ),
                  );
                }
                return ListView(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final row in rows.reversed)
                      if (row.divider)
                        const _SessionDivider()
                      else
                        _Bubble(
                          message: row.message!,
                          onOpen: widget.onOpen,
                          caseId: widget.caseId,
                        ),
                  ],
                );
              },
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            ErrorText(_error!),
          ],
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _question,
                  enabled: !_busy,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(hintText: 'Message'),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Send',
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  disabledBackgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.38,
                  ),
                  fixedSize: const Size(48, 48),
                  minimumSize: const Size(48, 48),
                ),
                onPressed: _busy ? null : _send,
                icon: _busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            vetBuddyFooter,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionDivider extends StatelessWidget {
  const _SessionDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(
          'New session',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.caseId,
    required this.onOpen,
  });

  final VetBuddyMessage message;
  final String caseId;
  final void Function(String route) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = !message.fromAssistant;
    final fill = mine
        ? theme.colorScheme.secondary
        : theme.colorScheme.surfaceContainerLow;
    final ink = mine
        ? theme.colorScheme.onSecondary
        : theme.colorScheme.onSurface;
    final links = [
      for (final link in message.links)
        if (vetBuddyLocation(caseId, link) != null) link,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(mine ? 16 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 16),
                  ),
                  border: mine
                      ? null
                      : Border.all(color: theme.colorScheme.outline),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Text(
                    message.content,
                    style: theme.textTheme.bodyMedium?.copyWith(color: ink),
                  ),
                ),
              ),
            ),
          ),
          if (message.createdAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                chatTimeLabel(message.createdAt!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (links.isNotEmpty)
            Wrap(
              spacing: 4,
              children: [
                for (final link in links)
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => onOpen(vetBuddyLocation(caseId, link)!),
                    child: Text(link.label),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
