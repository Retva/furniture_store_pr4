import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../models/entity.dart';
import '../models/list_query.dart';
import '../state/entity_list_notifier.dart';
import '../state/reference_data_notifier.dart';
import 'dialogs.dart';
import 'entity_card_list.dart';
import 'entity_table.dart';
import 'list_state_body.dart';
import 'pagination_bar.dart';
import 'record_actions.dart';
import 'selection_bar.dart';

/// Общий экран списка для всех пяти сущностей: фильтры, таблица или
/// карточки, страницы, выделение, удаление и восстановление.
///
/// Экран конкретной сущности передаёт только то, что у неё своё: колонки,
/// фильтры и подписи. [N] — тип notifier'а, под которым он лежит в provider.
class EntityListPage<
  T extends Entity,
  Q extends ListQuery,
  N extends EntityListNotifier<T, Q>
>
    extends StatefulWidget {
  const EntityListPage({
    super.key,
    required this.query,
    required this.basePath,
    required this.createLabel,
    required this.nameOf,
    required this.filters,
    required this.columns,
    required this.cardSubtitle,
    this.cardDetails,
    required this.emptyTitle,
  });

  final Q query;

  /// `/products` — от него строятся адреса карточки, формы и создания.
  final String basePath;
  final String createLabel;
  final String Function(T item) nameOf;
  final Widget Function(Q query, ValueChanged<ListQuery> go, bool compact)
  filters;
  final List<TableColumnSpec<T>> Function(void Function(T) open) columns;
  final String Function(T item) cardSubtitle;
  final Widget Function(T item)? cardDetails;
  final String emptyTitle;

  @override
  State<EntityListPage<T, Q, N>> createState() =>
      _EntityListPageState<T, Q, N>();
}

class _EntityListPageState<
  T extends Entity,
  Q extends ListQuery,
  N extends EntityListNotifier<T, Q>
>
    extends State<EntityListPage<T, Q, N>> {
  N get _notifier => context.read<N>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.applyQuery(widget.query, force: true);
      context.read<ReferenceDataNotifier>().load();
    });
  }

  @override
  void didUpdateWidget(EntityListPage<T, Q, N> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifier.applyQuery(widget.query);
      });
    }
  }

  void _go(ListQuery query) => context.go(query.toLocation());

  void _open(T item) => context.go('${widget.basePath}/${item.id}');

  void _edit(T item) => context.go('${widget.basePath}/${item.id}/edit');

  Future<void> _run(Future<Object?> Function() action, String success) async {
    final refs = context.read<ReferenceDataNotifier>();
    final ok = await runWithFeedback(context, action, success: (_) => success);
    if (ok) await refs.load();
  }

  Future<void> _softDelete(T item) async {
    final name = widget.nameOf(item);
    final confirmed = await confirmAction(
      context,
      title: 'Удалить «$name»?',
      message:
          'Запись пропадёт из списка. Вернуть её можно, включив '
          '«Удалённые» и нажав «Восстановить».',
      confirmLabel: 'Удалить',
    );
    if (!confirmed || !mounted) return;
    await _run(() => _notifier.softDelete(item.id), 'Запись «$name» удалена');
  }

  Future<void> _hardDelete(T item) async {
    final name = widget.nameOf(item);
    final confirmed = await confirmAction(
      context,
      title: 'Удалить навсегда?',
      message: '«$name» будет стёрт без возможности восстановления.',
      confirmLabel: 'Удалить навсегда',
    );
    if (!confirmed || !mounted) return;
    await _run(
      () => _notifier.hardDelete(item.id),
      'Запись «$name» удалена навсегда',
    );
  }

  Future<void> _restore(T item) => _run(
    () => _notifier.restore(item.id),
    'Запись «${widget.nameOf(item)}» восстановлена',
  );

  Future<void> _deleteSelected() async {
    final count = _notifier.selected.length;
    final confirmed = await confirmAction(
      context,
      title: 'Удалить выбранные записи?',
      message: 'Будет удалено записей: $count. Их можно будет восстановить.',
      confirmLabel: 'Удалить $count',
    );
    if (!confirmed || !mounted) return;
    final refs = context.read<ReferenceDataNotifier>();
    final ok = await runWithFeedback(
      context,
      _notifier.deleteSelected,
      success: (deleted) => 'Удалено записей: $deleted',
    );
    if (ok) await refs.load();
  }

  List<Widget> _actions(T item) => recordActions(
    isDeleted: item.isDeleted,
    onEdit: () => _edit(item),
    onSoftDelete: () => _softDelete(item),
    onRestore: () => _restore(item),
    onHardDelete: () => _hardDelete(item),
    busy: _notifier.isBusy(item.id),
  );

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<N>();
    context.watch<ReferenceDataNotifier>();
    final query = widget.query;
    final compact = screenSizeOf(context) == ScreenSize.compact;

    final createButton = FilledButton.icon(
      onPressed: () => context.go('${widget.basePath}/new'),
      icon: const Icon(Icons.add),
      label: Text(widget.createLabel),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (compact) ...[
          Align(alignment: Alignment.centerLeft, child: createButton),
          const SizedBox(height: 12),
          widget.filters(query, _go, compact),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: widget.filters(query, _go, compact)),
              const SizedBox(width: 12),
              createButton,
            ],
          ),
        const SizedBox(height: 12),
        if (notifier.hasSelection) ...[
          SelectionBar(
            count: notifier.selected.length,
            onClear: notifier.clearSelection,
            onDelete: _deleteSelected,
            busy: notifier.deletingSelection,
          ),
          const SizedBox(height: 12),
        ],
        ListStateBody<T>(
          state: notifier.state,
          hasFilters: query.hasFilters,
          onRetry: notifier.load,
          onResetFilters: () => _go(query.cleared()),
          onGoToPage: (page) => _go(query.withPage(page)),
          emptyTitle: widget.emptyTitle,
          emptyMessage:
              'Нажмите «${widget.createLabel}», чтобы добавить '
              'первую запись.',
          builder: (result) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact)
                EntityCardList<T>(
                  items: result.items,
                  selected: notifier.selected,
                  onToggleSelect: notifier.toggleSelection,
                  onOpen: _open,
                  actions: _actions,
                  title: widget.nameOf,
                  subtitle: widget.cardSubtitle,
                  details: widget.cardDetails,
                )
              else
                EntityTable<T>(
                  items: result.items,
                  selected: notifier.selected,
                  onToggleSelect: notifier.toggleSelection,
                  onSelectAll: notifier.setSelection,
                  sortField: query.sortField,
                  sortAscending: query.sortAscending,
                  onSort: (field) => _go(query.withSort(field)),
                  actions: _actions,
                  columns: widget.columns(_open),
                ),
              const SizedBox(height: 12),
              PaginationBar(
                result: result,
                onPageChanged: (page) => _go(query.withPage(page)),
                onSizeChanged: (size) => _go(query.withSize(size)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
