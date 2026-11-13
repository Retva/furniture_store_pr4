import 'package:flutter/material.dart';

import '../models/page_result.dart';
import '../state/list_state.dart';
import 'state_views.dart';

/// Тело экрана списка для каждого из состояний: загрузка, данные, пусто,
/// ошибка.
///
/// Обобщённое: экрану остаётся описать, как рисовать саму страницу записей
/// ([builder]), а разбор состояний одинаков для всех списков.
class ListStateBody<T> extends StatelessWidget {
  const ListStateBody({
    super.key,
    required this.state,
    required this.hasFilters,
    required this.builder,
    required this.onRetry,
    required this.onResetFilters,
    required this.onGoToPage,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final ListState<T> state;
  final bool hasFilters;
  final Widget Function(PageResult<T> result) builder;
  final VoidCallback onRetry;
  final VoidCallback onResetFilters;
  final ValueChanged<int> onGoToPage;

  /// Что сказать, когда записей нет совсем, без всяких фильтров.
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    // switch по запечатанному классу: если добавить новое состояние и
    // забыть его здесь, компилятор не соберёт проект.
    return switch (state) {
      ListLoading<T>(:final previous) =>
        previous == null
            ? const LoadingView()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Старые данные остаются на месте, сверху — тонкая полоса
                  // загрузки. Таблица не мигает при каждой смене страницы.
                  const LinearProgressIndicator(minHeight: 3),
                  IgnorePointer(child: _content(previous)),
                ],
              ),
      ListLoaded<T>(:final result) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [const SizedBox(height: 3), _content(result)],
      ),
      ListFailed<T>(:final message) => ErrorView(
        message: message,
        onRetry: onRetry,
      ),
    };
  }

  Widget _content(PageResult<T> result) {
    if (!result.isEmpty) return builder(result);

    // Записи есть, но не на этой странице: адрес с page=99 или удалили
    // последние записи последней страницы.
    if (result.total > 0) {
      return EmptyView(
        icon: Icons.find_in_page_outlined,
        title: 'На странице ${result.page} записей нет',
        message: 'Всего страниц: ${result.totalPages}.',
        actionLabel: 'К последней странице',
        onAction: () => onGoToPage(result.totalPages),
      );
    }

    if (hasFilters) {
      return EmptyView(
        title: 'Ничего не найдено',
        message:
            'Под выбранные условия не подошла ни одна запись. '
            'Попробуйте изменить поиск или фильтры.',
        actionLabel: 'Сбросить фильтры',
        onAction: onResetFilters,
      );
    }

    return EmptyView(
      icon: Icons.inventory_2_outlined,
      title: emptyTitle,
      message: emptyMessage,
    );
  }
}
