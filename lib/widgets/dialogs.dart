import 'package:flutter/material.dart';

import '../repositories/repository_exception.dart';

/// Диалог подтверждения. Возвращает `true`, только если нажали кнопку
/// действия; закрытие крестиком, Esc или щелчком мимо — это «нет».
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(message),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Ширина всплывающего сообщения. На узком окне — во всю ширину: заданная
/// ширина больше экрана привела бы к ошибке раскладки.
double? _snackWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 600 ? 420 : null;

void showMessage(BuildContext context, String text, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;
  final width = _snackWidth(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? scheme.error : null,
        behavior: SnackBarBehavior.floating,
        width: width,
      ),
    );
}

/// Выполняет действие с данными и сообщает об итоге.
///
/// Удаление может не пройти — например, при сбое сети. Тогда человек должен
/// увидеть причину, а не молчаливо неизменившийся список.
Future<bool> runWithFeedback(
  BuildContext context,
  Future<Object?> Function() action, {
  required String Function(Object? result) success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;
  final width = _snackWidth(context);
  try {
    final result = await action();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(success(result)),
          behavior: SnackBarBehavior.floating,
          width: width,
        ),
      );
    return true;
  } catch (error) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error is RepositoryException
                ? error.message
                : 'Действие не выполнено: $error',
          ),
          backgroundColor: scheme.error,
          behavior: SnackBarBehavior.floating,
          width: width,
        ),
      );
    return false;
  }
}
