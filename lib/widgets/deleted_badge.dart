import 'package:flutter/material.dart';

/// Пометка «удалён» рядом с названием логически удалённой записи —
/// обычный приглушённый текст.
class DeletedBadge extends StatelessWidget {
  const DeletedBadge({super.key, this.label = 'удалён'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      '($label)',
      style: TextStyle(color: Theme.of(context).colorScheme.outline),
    );
  }
}
