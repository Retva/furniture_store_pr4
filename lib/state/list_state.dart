import '../models/page_result.dart';

/// Состояние экрана списка.
sealed class ListState<T> {
  const ListState();
}

final class ListLoading<T> extends ListState<T> {
  const ListLoading({this.previous});

  final PageResult<T>? previous;
}

final class ListLoaded<T> extends ListState<T> {
  const ListLoaded(this.result);

  final PageResult<T> result;
}

final class ListFailed<T> extends ListState<T> {
  const ListFailed(this.message);

  final String message;
}
