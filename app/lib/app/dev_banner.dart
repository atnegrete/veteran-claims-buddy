import 'package:flutter/material.dart';

class DevBanner extends StatelessWidget {
  const DevBanner({super.key, this.projectId});

  final String? projectId;

  @override
  Widget build(BuildContext context) {
    final label = projectId == null || projectId!.isEmpty
        ? 'DEV'
        : 'DEV · $projectId';
    return ColoredBox(
      color: const Color(0xFFB45309),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 28,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
