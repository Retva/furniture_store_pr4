import 'package:flutter/material.dart';

/// Кнопки действий над записью в строке таблицы или в карточке.
/// Действующую запись можно изменить и удалить, удалённую — восстановить
/// или стереть насовсем.
List<Widget> recordActions({
  required bool isDeleted,
  required VoidCallback onEdit,
  required VoidCallback onSoftDelete,
  required VoidCallback onRestore,
  required VoidCallback onHardDelete,
  bool busy = false,
}) {
  // Пока запрос по записи не завершён, кнопки неактивны.
  VoidCallback? unlessBusy(VoidCallback action) => busy ? null : action;
  return [
    if (!isDeleted) ...[
      IconButton(
        tooltip: 'Изменить',
        icon: const Icon(Icons.edit_outlined),
        onPressed: unlessBusy(onEdit),
      ),
      IconButton(
        tooltip: 'Удалить (можно восстановить)',
        icon: const Icon(Icons.delete_outline),
        onPressed: unlessBusy(onSoftDelete),
      ),
    ] else ...[
      IconButton(
        tooltip: 'Восстановить',
        icon: const Icon(Icons.restore_from_trash_outlined),
        onPressed: unlessBusy(onRestore),
      ),
      IconButton(
        tooltip: 'Удалить навсегда',
        icon: const Icon(Icons.delete_forever_outlined),
        onPressed: unlessBusy(onHardDelete),
      ),
    ],
  ];
}
