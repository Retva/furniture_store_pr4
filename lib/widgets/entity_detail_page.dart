import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/formatting.dart';
import '../models/entity.dart';
import '../state/detail_state.dart';
import '../state/entity_detail_notifier.dart';
import '../state/reference_data_notifier.dart';
import 'deleted_badge.dart';
import 'dialogs.dart';
import 'info_table.dart';
import 'state_views.dart';

/// Общий экран карточки записи: заголовок, таблица «поле — значение»,
/// изменение, удаление и восстановление.
class EntityDetailPage<T extends Entity> extends StatelessWidget {
  const EntityDetailPage({
    super.key,
    required this.basePath,
    required this.backLabel,
    required this.backLocation,
    required this.title,
    required this.rows,
    this.subtitle,
    this.extraActions,
  });

  final String basePath;
  final String backLabel;

  /// Куда вернуться: список с теми фильтрами, с которыми его оставили.
  final String Function(BuildContext context) backLocation;
  final String Function(T item) title;
  final String Function(T item)? subtitle;
  final List<(String, Widget)> Function(BuildContext context, T item) rows;
  final List<Widget> Function(BuildContext context, T item)? extraActions;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<EntityDetailNotifier<T>>();
    context.watch<ReferenceDataNotifier>();

    final Widget body = switch (notifier.state) {
      DetailLoading() => const LoadingView(),
      DetailNotFound() => EmptyView(
        title: 'Запись не найдена',
        message: 'Возможно, её удалили насовсем или в ссылке ошибка.',
        actionLabel: backLabel,
        onAction: () => context.go(basePath),
      ),
      DetailFailed(:final message) => ErrorView(
        message: message,
        onRetry: notifier.load,
      ),
      DetailLoaded(:final item) => _details(context, notifier, item),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(backLocation(context)),
            icon: const Icon(Icons.arrow_back),
            label: Text(backLabel),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Breakpoints.readableWidth,
            ),
            child: body,
          ),
        ),
      ],
    );
  }

  Widget _details(
    BuildContext context,
    EntityDetailNotifier<T> notifier,
    T item,
  ) {
    final theme = Theme.of(context);
    final name = title(item);

    Future<void> run(
      Future<void> Function() action,
      String success, {
      bool leave = false,
    }) async {
      final refs = context.read<ReferenceDataNotifier>();
      final ok = await runWithFeedback(
        context,
        action,
        success: (_) => success,
      );
      if (!ok) return;
      await refs.load();
      if (leave && context.mounted) context.go(backLocation(context));
    }

    Future<void> softDelete() async {
      final confirmed = await confirmAction(
        context,
        title: 'Удалить «$name»?',
        message: 'Запись пропадёт из списка, но её можно будет восстановить.',
        confirmLabel: 'Удалить',
      );
      if (confirmed && context.mounted) {
        await run(notifier.softDelete, 'Запись удалена');
      }
    }

    Future<void> hardDelete() async {
      final confirmed = await confirmAction(
        context,
        title: 'Удалить навсегда?',
        message: '«$name» будет стёрт без возможности восстановления.',
        confirmLabel: 'Удалить навсегда',
      );
      if (confirmed && context.mounted) {
        await run(notifier.hardDelete, 'Запись удалена навсегда', leave: true);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (subtitle != null)
              Text(
                subtitle!(item),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (item.isDeleted)
              DeletedBadge(label: 'удалён ${formatDate(item.deletedAt!)}'),
          ],
        ),
        const Divider(height: 32),
        InfoTable(rows: rows(context, item)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (!item.isDeleted) ...[
              FilledButton.icon(
                onPressed: notifier.busy
                    ? null
                    : () => context.go('$basePath/${item.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Изменить'),
              ),
              OutlinedButton.icon(
                onPressed: notifier.busy ? null : softDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Удалить'),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: notifier.busy
                    ? null
                    : () => run(notifier.restore, 'Запись восстановлена'),
                icon: const Icon(Icons.restore_from_trash_outlined),
                label: const Text('Восстановить'),
              ),
              OutlinedButton.icon(
                onPressed: notifier.busy ? null : hardDelete,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Удалить навсегда'),
              ),
            ],
            ...?extraActions?.call(context, item),
          ],
        ),
      ],
    );
  }
}
