import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import '../../forms/text_input_chain.dart';
import '../../support/support_repository.dart';
import '../../support/support_ticket.dart';
import '../auth/auth_scaffold.dart';
import 'shell_pages.dart';
import 'signed_in_bar.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(supportTicketsProvider);
    return ShellPage(
      title: 'Support',
      wrapInCard: false,
      child: Column(
        children: [
          const SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email'),
                SizedBox(height: 8),
                SelectableText(supportEmail),
                SizedBox(height: 12),
                Text(supportPrivacyNote),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: tickets.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Text('Tickets could not be opened. Try again.'),
              data: (items) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (items.isEmpty)
                    const Text('No tickets yet.')
                  else
                    for (final ticket in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(ticket.subject),
                        subtitle: Text(
                          '${supportStatusLabel(ticket.status)} · ${supportCategoryLabel(ticket.category)}',
                        ),
                        onTap: () =>
                            context.go(AuthRoutes.supportTicket(ticket.id)),
                      ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go(AuthRoutes.supportNew),
                    child: const Text('New ticket'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NewSupportTicketScreen extends ConsumerStatefulWidget {
  const NewSupportTicketScreen({super.key});

  @override
  ConsumerState<NewSupportTicketScreen> createState() =>
      _NewSupportTicketScreenState();
}

class _NewSupportTicketScreenState
    extends ConsumerState<NewSupportTicketScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  var _category = 'account';
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!supportSubjectOk(_subject.text) || !supportMessageOk(_message.text)) {
      setState(() => _error = 'Add a subject and a message.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(supportRepositoryProvider)
          .createTicket(
            uid: _signedInUid(ref),
            subject: _subject.text,
            category: _category,
            message: _message.text,
          );
      if (mounted) context.go(AuthRoutes.supportTicket(id));
    } on SupportFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'That ticket could not be sent. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShellPage(
      title: 'New ticket',
      child: TextInputChain(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(supportPrivacyNote),
            const SizedBox(height: 16),
            ChainTextField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Subject'),
              maxLength: 120,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final entry in supportCategories.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) setState(() => _category = value);
                    },
            ),
            const SizedBox(height: 12),
            ChainTextField(
              controller: _message,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: Text(_busy ? 'Sending…' : 'Send ticket'),
            ),
          ],
        ),
      ),
    );
  }
}

class SupportTicketScreen extends ConsumerStatefulWidget {
  const SupportTicketScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<SupportTicketScreen> createState() =>
      _SupportTicketScreenState();
}

class _SupportTicketScreenState extends ConsumerState<SupportTicketScreen> {
  final _reply = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send(SupportTicket ticket) async {
    if (!supportMessageOk(_reply.text)) {
      setState(() => _error = 'Add a message.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(supportRepositoryProvider)
          .reply(
            uid: _signedInUid(ref),
            ticketId: ticket.id,
            message: _reply.text,
            currentStatus: ticket.status,
          );
      _reply.clear();
    } on SupportFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'That reply could not be sent. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close(SupportTicket ticket) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(supportRepositoryProvider)
          .close(uid: _signedInUid(ref), ticketId: ticket.id);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'That ticket could not be closed. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = ref.watch(supportTicketProvider(widget.ticketId));
    final messages = ref.watch(supportMessagesProvider(widget.ticketId));
    return ticket.when(
      loading: () => const ShellPage(
        title: 'Ticket',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const ShellPage(
        title: 'Ticket',
        child: Text('That ticket could not be opened. Try again.'),
      ),
      data: (item) {
        if (item == null) {
          return ShellPage(
            title: 'Ticket',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('That ticket is not on this account.'),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go(AuthRoutes.support),
                  child: const Text('All tickets'),
                ),
              ],
            ),
          );
        }
        return ShellPage(
          title: item.subject,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${supportStatusLabel(item.status)} · ${supportCategoryLabel(item.category)}',
              ),
              const SizedBox(height: 12),
              messages.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    const Text('Messages could not be opened. Try again.'),
                data: (items) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final message in items) ...[
                      Text(message.body),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              if (!item.isClosed) ...[
                const Text(supportPrivacyNote),
                const SizedBox(height: 12),
                ChainTextField(
                  controller: _reply,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: const InputDecoration(labelText: 'Reply'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : () => _send(item),
                  child: Text(_busy ? 'Sending…' : 'Send reply'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _close(item),
                  child: const Text('Close ticket'),
                ),
              ] else
                const Text('This ticket is closed.'),
            ],
          ),
        );
      },
    );
  }
}

String _signedInUid(WidgetRef ref) {
  final uid = ref.read(authControllerProvider).session?.uid;
  if (uid == null) {
    throw const SupportFailure('Sign in again, then try again.');
  }
  return uid;
}
