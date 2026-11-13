import 'package:flutter/foundation.dart';

import '../models/entity.dart';
import '../repositories/crud_repository.dart';
import '../repositories/repository_exception.dart';
import 'detail_state.dart';

/// Состояние экрана карточки одной записи — товара или производителя.
/// Создаётся на каждый открытый экран карточки и уничтожается вместе с ним, поэтому номер записи передаётся в конструктор.
class EntityDetailNotifier<T extends Entity> extends ChangeNotifier {
  EntityDetailNotifier(this._repository, this.id);

  final CrudRepository<T, dynamic> _repository;
  final int id;

  DetailState<T> _state = DetailLoading<T>();
  bool _disposed = false;

  DetailState<T> get state => _state;

  /// Идёт удаление или восстановление — кнопки карточки неактивны.
  bool _busy = false;
  bool get busy => _busy;

  /// [quiet] — перечитать запись, не показывая индикатор загрузки
  /// (например, после оформления заказа изменился остаток).
  Future<void> load({bool quiet = false}) async {
    if (!quiet || _state is! DetailLoaded<T>) {
      _state = DetailLoading<T>();
      _notify();
    }
    try {
      final item = await _repository.findById(id);
      _state = item == null ? DetailNotFound<T>() : DetailLoaded<T>(item);
    } catch (error) {
      _state = DetailFailed<T>(
        error is RepositoryException
            ? error.message
            : 'Не удалось загрузить запись: $error',
      );
    }
    _notify();
  }

  Future<void> softDelete() => _run(() async {
    await _repository.softDelete(id);
    await load(quiet: true);
  });

  Future<void> restore() => _run(() async {
    await _repository.restore(id);
    await load(quiet: true);
  });

  /// После физического удаления показывать нечего — экран сам уходит к списку, поэтому повторная загрузка не нужна.
  Future<void> hardDelete() => _run(() => _repository.hardDelete(id));

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    _notify();
    try {
      await action();
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
