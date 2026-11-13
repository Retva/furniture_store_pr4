/// Состояние экрана карточки одной записи.
sealed class DetailState<T> {
  const DetailState();
}

final class DetailLoading<T> extends DetailState<T> {
  const DetailLoading();
}

final class DetailLoaded<T> extends DetailState<T> {
  const DetailLoaded(this.item);

  final T item;
}

/// Записи с таким номером нет — например, ссылку открыли после того, как
/// запись удалили насовсем. Это не ошибка сети, и показывать «Повторить»
/// здесь бессмысленно.
final class DetailNotFound<T> extends DetailState<T> {
  const DetailNotFound();
}

final class DetailFailed<T> extends DetailState<T> {
  const DetailFailed(this.message);

  final String message;
}
