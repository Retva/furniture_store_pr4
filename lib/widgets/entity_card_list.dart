import 'package:flutter/material.dart';

import '../models/entity.dart';
import 'deleted_badge.dart';

/// Список карточек для узкого окна — пара к `EntityTable`.
///
/// На экране телефона таблица из шести колонок не помещается, и читать её,
/// прокручивая вбок, неудобно. Поэтому при ширине меньше 600 пикселей те же
/// записи показываются карточками: заголовок, пара строк подробностей,
/// флажок выделения и кнопки действий.
class EntityCardList<T extends Entity> extends StatelessWidget {
  const EntityCardList({
    super.key,
    required this.items,
    required this.title,
    required this.onOpen,
    this.subtitle,
    this.details,
    this.selected = const {},
    this.onToggleSelect,
    this.actions,
  });

  final List<T> items;
  final String Function(T item) title;
  final String Function(T item)? subtitle;

  /// Строка с главными цифрами — цена и остаток, год основания.
  final Widget Function(T item)? details;
  final void Function(T item) onOpen;

  final Set<int> selected;
  final ValueChanged<int>? onToggleSelect;
  final List<Widget> Function(T item)? actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items) ...[
          _EntityCard<T>(
            item: item,
            title: title(item),
            subtitle: subtitle?.call(item),
            details: details?.call(item),
            selected: selected.contains(item.id),
            onToggleSelect: onToggleSelect == null || item.isDeleted
                ? null
                : () => onToggleSelect!(item.id),
            onOpen: () => onOpen(item),
            actions: actions?.call(item) ?? const [],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _EntityCard<T extends Entity> extends StatelessWidget {
  const _EntityCard({
    required this.item,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.selected,
    required this.onToggleSelect,
    required this.onOpen,
    required this.actions,
  });

  final T item;
  final String title;
  final String? subtitle;
  final Widget? details;
  final bool selected;
  final VoidCallback? onToggleSelect;
  final VoidCallback onOpen;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onToggleSelect != null)
                Checkbox(value: selected, onChanged: (_) => onToggleSelect!())
              else
                const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          if (item.isDeleted) const DeletedBadge(),
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (details != null) ...[
                        const SizedBox(height: 6),
                        details!,
                      ],
                      if (actions.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(children: actions),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
