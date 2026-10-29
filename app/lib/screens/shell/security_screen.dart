import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../app/app_ui.dart';
import '../../auth/auth_controller.dart';
import '../../forms/text_input_chain.dart';
import '../../auth/auth_failure.dart';
import '../../auth/mfa_challenge.dart';
import '../../auth/phone_number.dart';
import '../auth/auth_scaffold.dart';
import 'shell_pages.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  var _adding = false;
  var _agreed = false;
  var _codeSent = false;
  var _busy = false;
  String? _message;
  var _messageIsError = true;
  String? _sentLabel;

  @override
  void dispose() {
    _password.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final e164 = toE164(_phone.text);
    if (_password.text.isEmpty) {
      _show('Enter your password before adding a phone.', error: true);
      return;
    }
    if (e164 == null) {
      _show('Enter a valid mobile number.', error: true);
      return;
    }
    if (!_agreed) {
      _show(
        'Agree to use this number for sign-in before sending a code.',
        error: true,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .reauthenticate(_password.text);
      await ref.read(authControllerProvider.notifier).sendEnrollmentCode(e164);
      setState(() {
        _codeSent = true;
        _sentLabel = maskPhoneNumber(e164);
      });
      _show('Enter the 6-digit code from the text message.', error: false);
    } on AuthFailure catch (failure) {
      _show(failure.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCode() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      _show('Enter the 6-digit code.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .confirmEnrollmentCode(code);
      _password.clear();
      _phone.clear();
      _code.clear();
      setState(() {
        _adding = false;
        _codeSent = false;
        _agreed = false;
      });
      _show('Phone added.', error: false);
    } on AuthFailure catch (failure) {
      _show(failure.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(
    PhoneFactorHint factor, {
    required bool onlyFactor,
  }) async {
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove this phone?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(factor.label),
              const SizedBox(height: 12),
              if (onlyFactor)
                const Text(
                  'This is the only text-message check. Removing it closes the app until you add a phone again.',
                ),
              if (onlyFactor) const SizedBox(height: 12),
              ChainTextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                maxLength: 128,
                countVisibleFrom: authCountVisibleFrom,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: dangerFilledStyle().merge(
                FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    final entered = password.text;
    password.dispose();
    if (confirmed != true || !mounted) return;
    if (entered.isEmpty) {
      _show('Enter your password before removing a phone.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .removePhoneFactor(password: entered, factorUid: factor.uid);
    } on AuthFailure catch (failure) {
      _show(failure.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message, {required bool error}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageIsError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final factors =
        ref.watch(authControllerProvider).session?.factors ?? const [];
    final theme = Theme.of(context);
    return ShellPage(
      title: 'Security',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Text-message checks', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (factors.isEmpty) const Text('No phone is enrolled.'),
          for (final factor in factors) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(factor.label)),
                TextButton(
                  style: dangerTextStyle(),
                  onPressed: _busy
                      ? null
                      : () => _remove(factor, onlyFactor: factors.length == 1),
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (!_adding)
            OutlinedButton(
              onPressed: _busy ? null : () => setState(() => _adding = true),
              child: const Text('Add a phone'),
            )
          else
            TextInputChain(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ChainTextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    maxLength: 128,
                    countVisibleFrom: authCountVisibleFrom,
                  ),
                  const SizedBox(height: 12),
                  if (!_codeSent) ...[
                    MobileNumberField(controller: _phone),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _agreed,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _agreed = value ?? false),
                      title: const Text(
                        'I agree to use this mobile number as a second sign-in check.',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _sendCode,
                      child: Text(_busy ? 'Sending…' : 'Send code'),
                    ),
                  ] else ...[
                    Text('Code sent for $_sentLabel.'),
                    const SizedBox(height: 12),
                    ChainTextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '6-digit code',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _confirmCode,
                      child: Text(_busy ? 'Checking…' : 'Confirm phone'),
                    ),
                  ],
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _adding = false;
                            _codeSent = false;
                            _message = null;
                          }),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            InfoNote(
              text: _message!,
              tone: _messageIsError ? InfoNoteTone.danger : InfoNoteTone.info,
            ),
          ],
          const SizedBox(height: 24),
          Text('Lost phone', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const InfoNote(
            text:
                'The text-message check cannot be skipped. Email $supportEmail and we will verify it is you before changing the phone. Do not send a Social Security number or medical records.',
          ),
        ],
      ),
    );
  }
}
