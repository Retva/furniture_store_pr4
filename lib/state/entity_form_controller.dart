import 'package:flutter/foundation.dart';

import '../models/entity.dart';
import '../repositories/crud_repository.dart';
import '../repositories/repository_exception.dart';

sealed class FormLoadState<T> {
  const FormLoadState();
}

final class FormLoading<T> extends FormLoadState<T> {
  const FormLoading();
}

/// Можно показывать форму. [item] — `null` при создании новой записи.
final class FormReady<T> extends FormLoadState<T> {
  const FormReady(this.item);

  final T? item;
}

final class FormNotFound<T> extends FormLoadState<T> {
  const FormNotFound();
}

final class FormFailed<T> extends FormLoadState<T> {
  const FormFailed(this.message);

  final String message;
}

/// Загрузка записи для формы и её сохранение. Один класс и для создания
/// ([id] == null), и для изменения.
class EntityFormController<T extends Entity> extends ChangeNotifier {
  EntityFormController(this._repository, this.id);

  final CrudRepository<T, dynamic> _repository;
  final int? id;

  FormLoadState<T> _state = FormLoading<T>();
  bool _saving = false;
  bool _disposed = false;

  FormLoadState<T> get state => _state;
  bool get isEditing => id != null;
  bool get saving => _saving;

  Future<void> load() async {
    if (id == null) {
      _state = FormReady<T>(null);
      _notify();
      return;
    }
    _state = FormLoading<T>();
    _notify();
    try {
      final item = await _repository.findById(id!);
      _state = item == null ? FormNotFound<T>() : FormReady<T>(item);
    } catch (error) {
      _state = FormFailed<T>(
        error is RepositoryException ? error.message : '$error',
      );
    }
    _notify();
  }

  /// Создаёт или обновляет запись. Ошибки уникальности приходят как
  /// [ValidationException] — форма покажет их под полями.
  Future<T> save(T item) async {
    _saving = true;
    _notify();
    try {
      return isEditing
          ? await _repository.update(item)
          : await _repository.create(item);
    } finally {
      _saving = false;
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
