import 'package:flutter/material.dart';

import '../../app/app_badge.dart';
import '../../claim/claim_sections.dart';

/// A claim part's status, drawn only with [AppBadge].
class ProgressMark extends StatelessWidget {
  const ProgressMark({super.key, required this.status, this.label});

  final ClaimSectionStatus status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final hasLabel = label != null && label!.isNotEmpty;
    if (status == ClaimSectionStatus.notStarted && !hasLabel) {
      return const SizedBox.shrink();
    }
    if (status == ClaimSectionStatus.notStarted) {
      return AppBadge.quiet(label: label);
    }
    if (status == ClaimSectionStatus.inProgress) {
      return AppBadge.primary(label: hasLabel ? label! : 'In progress');
    }
    if (hasLabel) {
      return AppBadge.success(label: label, icon: Icons.check);
    }
    return const AppBadge.success(icon: Icons.check);
  }
}
