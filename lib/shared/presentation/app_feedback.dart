import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/value_objects/money.dart';

String paymentStatusLabel({required Money paid, required Money pending}) {
  if (pending.isZero) return 'Paid';
  if (paid.isZero) return 'Pending';
  return 'Partial';
}

String friendlyErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final message =
      error.toString().replaceFirst(RegExp(r'^\w*(Exception|Error):\s*'), '');
  final lower = message.toLowerCase();
  if (lower.contains('network') ||
      lower.contains('unavailable') ||
      lower.contains('socket') ||
      lower.contains('offline')) {
    return 'Internet is unavailable. Your saved local work is safe.';
  }
  if (lower.contains('permission') || lower.contains('not allowed')) {
    return 'Your role does not allow this action. Ask the owner or admin for access.';
  }
  if (lower.contains('revoked')) {
    return 'Your access has been revoked. Please contact the company owner.';
  }
  if (lower.contains('negative') ||
      lower.contains('greater than') ||
      lower.contains('required') ||
      lower.contains('invalid') ||
      lower.contains('cannot exceed')) {
    return message;
  }
  final looksTechnical = lower.contains('stack trace') ||
      lower.contains('package:') ||
      lower.contains('firebaseexception') ||
      lower.contains('sqlite') ||
      message.contains('{') ||
      message.contains('#0');
  if (!looksTechnical && message.trim().isNotEmpty && message.length <= 180) {
    return message;
  }
  return kDebugMode && message.trim().isNotEmpty ? message : fallback;
}

Future<bool> confirmDestructiveAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
