import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/profile.dart';
import '../../forms/text_input_chain.dart';
import '../../auth/auth_controller.dart';
import '../../onboarding/onboarding_progress.dart';
import 'shell_pages.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(onboardingDocProvider);
    return account.when(
      loading: () => const ShellPage(
        title: 'Profile',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const ShellPage(
        title: 'Profile',
        child: Text('Profile could not be opened. Try again.'),
      ),
      data: (data) => _ProfileForm(data: data),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.data});

  final Map<String, dynamic>? data;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _name;
  late String _timezone;
  var _busy = false;
  String? _error;
  var _saved = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.data?['displayName'] as String? ?? '',
    );
    _timezone = profileTimezoneOrDefault(widget.data?['timezone'] as String?);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = normalizeProfileName(_name.text);
    if (!profileNameOk(name)) {
      setState(() => _error = 'Use 80 characters or fewer.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _saved = false;
    });
    try {
      await ref.read(saveProfileProvider)(
        displayName: name,
        timezone: _timezone,
      );
      if (mounted) setState(() => _saved = true);
    } on ProfileFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'That could not be saved. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    return ShellPage(
      title: 'Profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This is the name shown in the app. It is not a legal name.',
          ),
          const SizedBox(height: 16),
          ChainTextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
            maxLength: 80,
            onChanged: (_) => setState(() => _saved = false),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_timezone),
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
          const SizedBox(height: 16),
          Text(session?.email ?? ''),
          if (session?.maskedPhone != null) ...[
            const SizedBox(height: 8),
            Text(session!.maskedPhone!),
          ],
          const SizedBox(height: 8),
          Text(
            'Language: English',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_saved) ...[const SizedBox(height: 12), const Text('Saved.')],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
