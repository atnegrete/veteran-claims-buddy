import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/app_ui.dart';
import '../../forms/text_input_chain.dart';

const independentProductDisclaimer =
    'Veteran Claims Buddy is an independent service and is not affiliated with or endorsed by the U.S. Department of Veterans Affairs.';

const supportEmail = 'support@veteranclaimsbuddy.com';

const authSideDescription =
    'Keep the claim organized. You submit it yourself. Nothing here is filed.';

/// Shared frame for every signed-out gate.
///
/// A phone shows the mark, the form card, and the independence note. A wide
/// window puts a brand card beside the form.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.eyebrow,
    this.lead,
  });

  static const formWidth = 420.0;
  static const wideBreak = 880.0;

  final String title;
  final String? eyebrow;
  final String? lead;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= wideBreak;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 64,
                ),
                child: Center(
                  child: wide
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 380, child: _AuthBrand()),
                            const SizedBox(width: 40),
                            _form(),
                          ],
                        )
                      : _phone(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _phone() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: formWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PhoneBrand(),
          const SizedBox(height: 24),
          _form(),
          const SizedBox(height: 16),
          const InfoNote(text: independentProductDisclaimer),
        ],
      ),
    );
  }

  Widget _form() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: formWidth),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenIntro(eyebrow: eyebrow, title: title, lead: lead),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneBrand extends StatelessWidget {
  const _PhoneBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _Mark(size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Veteran Claims Buddy',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Mark(size: 56),
            const SizedBox(height: 20),
            const Eyebrow('Independent claim workspace'),
            const SizedBox(height: 10),
            Text('Veteran Claims Buddy', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const LeadText(authSideDescription),
            const SizedBox(height: 20),
            const InfoNote(text: independentProductDisclaimer),
          ],
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SvgPicture.asset(
        'assets/brand/logo-mark.svg',
        width: size,
        height: size,
      ),
    );
  }
}

/// A password field with a show and hide control.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  var _obscure = true;

  @override
  Widget build(BuildContext context) {
    final hidden = _obscure;
    return ChainTextField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: hidden,
      autofillHints: widget.autofillHints,
      maxLength: 128,
      countVisibleFrom: authCountVisibleFrom,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: Tooltip(
          message: hidden ? 'Show password' : 'Hide password',
          child: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet text path. It stays the size of its label.
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.alignment = Alignment.center,
  });

  final String label;
  final VoidCallback? onPressed;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// A muted prompt beside a quiet action, such as "New here? Create account".
class AuthSwitchLine extends StatelessWidget {
  const AuthSwitchLine({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  final String prompt;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: onPressed,
          child: Text(action),
        ),
      ],
    );
  }
}

class AuthMessageText extends StatelessWidget {
  const AuthMessageText(this.message, {super.key, this.isError = true});

  final String? message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: isError ? ErrorText(message!) : InfoNote(text: message!),
    );
  }
}
