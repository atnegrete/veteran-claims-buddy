import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const independentProductDisclaimer =
    'Veteran Claims Buddy is an independent service and is not affiliated with or endorsed by the U.S. Department of Veterans Affairs.';

const supportEmail = 'support@veteranclaimsbuddy.com';

const authSideDescription =
    'Keep the claim organized. You submit it yourself. Nothing here is filed.';

/// Shared frame for every signed-out gate. Phone stays one column. A wide
/// window puts the mark and a short description beside that column.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.child});

  static const formWidth = 400.0;
  static const wideBreak = 880.0;

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(width: 320, child: _AuthBrand()),
                            const SizedBox(width: 48),
                            _form(theme, showProductName: false),
                          ],
                        )
                      : _form(theme, showProductName: true),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _form(ThemeData theme, {required bool showProductName}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: formWidth),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showProductName) ...[
            Text(
              'Veteran Claims Buddy',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
          ],
          Text(title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: SvgPicture.asset(
                'assets/brand/logo-mark.svg',
                width: 48,
                height: 48,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Veteran Claims Buddy',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          authSideDescription,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
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
    final theme = Theme.of(context);
    final color = isError
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        message!,
        style: theme.textTheme.bodyMedium?.copyWith(color: color),
      ),
    );
  }
}
