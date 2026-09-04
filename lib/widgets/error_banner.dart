import 'package:flutter/material.dart';

/// A friendly error banner shown at the top of a form when an action fails.
///
/// Replaces the previous raw `Colors.red.shade100` containers so failures
/// read like feedback instead of dumped exceptions.
class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}