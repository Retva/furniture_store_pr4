import 'package:flutter/material.dart';

import '../models/entity.dart';
import 'deleted_badge.dart';

/// Описание одной колонки таблицы.
///
/// Таблица не знает, что в ней лежит — товары или производители. Всё, что
/// зависит от сущности, приходит снаружи: подпись, как нарисовать ячейку,
/// по какому полю сортировать.
class TableColumnSpec<T> {
  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
    this.tooltip,
    this.onTap,
  });

  final String label;

  /// Содержимое ячейки для записи.
  final Widget Function(T item) build;

  /// Имя поля сортировки. `null` — по колонке не сортируют, и щелчок по
  /// заголовку ничего не делает.
  final String? sortField;

  /// Числовая колонка выравнивается по правому краю.
  final bool numeric;

  final String? tooltip;

  /// Действие при щелчке по ячейке, например переход к карточке записи.
  /// Без него щелчок по строке переключает флажок выделения.
  final void Function(T item)? onTap;
}

/// Обобщённая таблица записей: сортировка по заголовкам, флажки выделения,
/// колонка действий, пометка удалённых записей.
///
/// Используется и для товаров, и для производителей — различается только
/// описание колонок. Без неё на каждую сущность пришлось бы писать свою
/// таблицу со своей сортировкой и своими флажками, то есть одно и то же
/// по нескольку раз.
class EntityTable<T extends Entity> extends StatelessWidget {
  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    this.selected = const {},
    this.onToggleSelect,
    this.onSelectAll,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
  });

  final List<TableColumnSpec<T>> columns;
  final List<T> items;

  /// Идентификаторы отмеченных записей.
  final Set<int> selected;

  /// Переключение флажка в строке. `null` — флажков нет вовсе.
  final ValueChanged<int>? onToggleSelect;

  /// Флажок в заголовке: отметить или снять все записи на странице.
  final void Function(List<int> ids, bool selected)? onSelectAll;

  final String? sortField;
  final bool sortAscending;
  final ValueChanged<String>? onSort;

  /// Кнопки в последней колонке строки.
  final List<Widget> Function(T item)? actions;

  @override
  Widget build(BuildContext context) {
    // Номер колонки, по которой сейчас отсортировано, — DataTable рисует
    // у её заголовка стрелку направления.
    final sortIndex = columns.indexWhere(
      (c) => c.sortField != null && c.sortField == sortField,
    );

    // Флажки есть только у действующих записей: удалённую повторно
    // «удалить выбранные» всё равно нельзя.
    final selectableIds = [
      for (final item in items)
        if (!item.isDeleted) item.id,
    ];

    final table = DataTable(
      showCheckboxColumn: onToggleSelect != null,
      sortColumnIndex: sortIndex == -1 ? null : sortIndex,
      sortAscending: sortAscending,
      onSelectAll: onSelectAll == null
          ? null
          : (value) => onSelectAll!(selectableIds, value ?? false),
      columns: [
        for (final column in columns)
          DataColumn(
            label: Text(column.label),
            numeric: column.numeric,
            tooltip:
                column.tooltip ??
                (column.sortField == null ? null : 'Сортировать'),
            // Направление считает не таблица, а запрос: повторный щелчок по
            // той же колонке разворачивает порядок, щелчок по другой —
            // сортирует по ней по возрастанию.
            onSort: column.sortField == null || onSort == null
                ? null
                : (_, _) => onSort!(column.sortField!),
          ),
        if (actions != null) const DataColumn(label: Text('Действия')),
      ],
      rows: [
        for (final item in items)
          DataRow(
            key: ValueKey(item.id),
            selected: selected.contains(item.id),
            onSelectChanged: onToggleSelect == null || item.isDeleted
                ? null
                : (_) => onToggleSelect!(item.id),
            cells: [
              for (final column in columns)
                DataCell(
                  _muteIfDeleted(context, item, column.build(item)),
                  onTap: column.onTap == null
                      ? null
                      : () => column.onTap!(item),
                ),
              if (actions != null)
                DataCell(
                  Row(mainAxisSize: MainAxisSize.min, children: actions!(item)),
                ),
            ],
          ),
      ],
    );

    // DataTable не прокручивается и не сжимается сам. На узком окне он
    // уехал бы за край, поэтому — горизонтальная прокрутка. Вертикальную
    // даёт список экрана, в котором лежит таблица.
    //
    // ConstrainedBox с minWidth и Center ставят таблицу по середине, если
    // она уже окна; если шире — её можно прокрутить вбок.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Center(child: table),
        ),
      ),
    );
  }

  /// Текст удалённой записи приглушается, чтобы её было видно сразу.
  Widget _muteIfDeleted(BuildContext context, T item, Widget child) {
    if (!item.isDeleted) return child;
    return DefaultTextStyle.merge(
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      child: child,
    );
  }
}

/// Колонка с названием записи: щелчок открывает карточку, у удалённой
/// записи рядом пометка «(удалён)».
TableColumnSpec<T> nameColumn<T extends Entity>({
  required String label,
  required String Function(T item) text,
  required void Function(T item) onOpen,
  String? sortField,
}) {
  return TableColumnSpec<T>(
    label: label,
    sortField: sortField,
    onTap: onOpen,
    build: (item) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(text(item), overflow: TextOverflow.ellipsis),
        ),
        if (item.isDeleted) ...[const SizedBox(width: 8), const DeletedBadge()],
      ],
    ),
  );
}
