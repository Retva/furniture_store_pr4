import 'package:flutter/foundation.dart';

import '../models/entity.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';
import '../repositories/crud_repository.dart';
import '../repositories/repository_exception.dart';
import 'list_state.dart';

/// Состояние экрана списка: условия отбора, текущая страница, выделение.
class EntityListNotifier<T extends Entity, Q extends ListQuery>
    extends ChangeNotifier {
  EntityListNotifier(this._repository, Q initialQuery) : _query = initialQuery;

  final CrudRepository<T, Q> _repository;

  Q _query;
  ListState<T> _state = ListLoading<T>();
  final Set<int> _selected = {};

  /// Записи, над которыми сейчас выполняется действие. Их кнопки
  /// неактивны, чтобы повторное нажатие не отправило второй запрос.
  final Set<int> _busy = {};
  bool _deletingSelection = false;

  int _requestId = 0;
  bool _disposed = false;

  Q get query => _query;
  ListState<T> get state => _state;

  Set<int> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;
  bool isSelected(int id) => _selected.contains(id);

  bool isBusy(int id) => _busy.contains(id);
  bool get deletingSelection => _deletingSelection;

  /// Последняя полученная страница — и во время загрузки следующей тоже.
  PageResult<T>? get currentResult => switch (_state) {
    ListLoaded(:final result) => result,
    ListLoading(:final previous) => previous,
    ListFailed() => null,
  };

  /// Загружает страницу по текущим условиям.
  Future<void> load() async {
    final requestId = ++_requestId;
    _state = ListLoading<T>(previous: currentResult);
    _notify();

    try {
      final result = await _repository.find(_query);
      if (requestId != _requestId) return;
      _state = ListLoaded<T>(result);
    } catch (error) {
      if (requestId != _requestId) return;
      _state = ListFailed<T>(_describe(error));
    }
    _notify();
  }

  Future<void> applyQuery(Q next, {bool force = false}) async {
    final unchanged = next == _query && _state is ListLoaded<T>;
    if (unchanged && !force) return;

    // Выделение теряет смысл при смене условий: отмеченные записи могли
    // уйти с экрана, и «удалить выбранные» удалило бы невидимое.
    if (next != _query) _selected.clear();
    _query = next;
    await load();
  }

  void toggleSelection(int id) {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    _notify();
  }

  /// Отметить или снять все записи из [ids] — флажок в заголовке таблицы.
  void setSelection(Iterable<int> ids, bool selected) {
    selected ? _selected.addAll(ids) : _selected.removeAll(ids);
    _notify();
  }

  void clearSelection() {
    _selected.clear();
    _notify();
  }

  /// Логически удаляет выбранные записи. Возвращает, сколько удалено.
  Future<int> deleteSelected() async {
    if (_deletingSelection) return 0;
    _deletingSelection = true;
    _notify();
    try {
      final count = await _repository.deleteMany(_selected.toList());
      _selected.clear();
      await load();
      return count;
    } finally {
      _deletingSelection = false;
      _notify();
    }
  }

  Future<void> softDelete(int id) => _track(id, () async {
    await _repository.softDelete(id);
    _selected.remove(id);
  });

  Future<void> hardDelete(int id) => _track(id, () async {
    await _repository.hardDelete(id);
    _selected.remove(id);
  });

  Future<void> restore(int id) => _track(id, () => _repository.restore(id));

  /// Выполняет действие над записью, пока её кнопки заблокированы, и
  /// перезагружает страницу.
  Future<void> _track(int id, Future<void> Function() action) async {
    if (!_busy.add(id)) return;
    _notify();
    try {
      await action();
      await load();
    } finally {
      _busy.remove(id);
      _notify();
    }
  }

  String _describe(Object error) => error is RepositoryException
      ? error.message
      : 'Не удалось загрузить список: $error';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
