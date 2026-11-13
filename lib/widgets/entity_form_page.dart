import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../models/entity.dart';
import '../repositories/repository_exception.dart';
import '../state/entity_form_controller.dart';
import '../state/reference_data_notifier.dart';
import '../state/unsaved_changes_guard.dart';
import 'dialogs.dart';
import 'form_fields.dart';
import 'state_views.dart';

/// Общий экран формы создания и изменения записи любой сущности.
///
/// Сущность описывает только своё: начальные значения, список полей и
/// сборку записи из значений. Загрузка, разметка, проверка, сохранение,
/// ошибки уникальности под полями и предупреждение о несохранённых
/// изменениях — здесь, один раз для всех.
class EntityFormPage<T extends Entity> extends StatefulWidget {
  const EntityFormPage({
    super.key,
    required this.basePath,
    required this.newTitle,
    required this.editTitle,
    required this.initialValues,
    required this.fields,
    required this.build,
  });

  final String basePath;
  final String newTitle;
  final String editTitle;
  final FormValues Function(T? item) initialValues;
  final List<FieldSpec> Function(FormValues values) fields;
  final T Function(FormValues values, T? original) build;

  @override
  State<EntityFormPage<T>> createState() => _EntityFormPageState<T>();
}

class _EntityFormPageState<T extends Entity> extends State<EntityFormPage<T>> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ReferenceDataNotifier>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EntityFormController<T>>();
    final refs = context.watch<ReferenceDataNotifier>();

    final Widget body = switch (controller.state) {
      FormLoading() => const LoadingView(),
      FormNotFound() => EmptyView(
        title: 'Запись не найдена',
        message: 'Возможно, её удалили насовсем.',
        actionLabel: 'К списку',
        onAction: () => context.go(widget.basePath),
      ),
      FormFailed(:final message) => ErrorView(
        message: message,
        onRetry: controller.load,
      ),
      FormReady(:final item) =>
        refs.status == ReferenceStatus.loading && refs.categories.isEmpty
            ? const LoadingView(label: 'Загружаем справочники…')
            : _FormBody<T>(page: widget, item: item),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
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
}

class _FormBody<T extends Entity> extends StatefulWidget {
  const _FormBody({super.key, required this.page, required this.item});

  final EntityFormPage<T> page;
  final T? item;

  @override
  State<_FormBody<T>> createState() => _FormBodyState<T>();
}

class _FormBodyState<T extends Entity> extends State<_FormBody<T>>
    implements FormScope {
  final _formKey = GlobalKey<FormState>();
  late final FormValues _initial = widget.page.initialValues(widget.item);
  late final FormValues _values = {..._initial};
  final Map<String, TextEditingController> _controllers = {};
  Map<String, String> _serverErrors = {};
  late final UnsavedChangesGuard _guard;

  @override
  void initState() {
    super.initState();
    _guard = context.read<UnsavedChangesGuard>();
  }

  bool get _isEditing => widget.item != null;

  bool get _dirty {
    for (final key in {..._initial.keys, ..._values.keys}) {
      final a = _initial[key];
      final b = _values[key];
      if (a is List && b is List) {
        if (a.length != b.length || !a.toSet().containsAll(b)) return true;
      } else if ((a ?? '') != (b ?? '')) {
        return true;
      }
    }
    return false;
  }

  String get _backLocation => _isEditing
      ? '${widget.page.basePath}/${widget.item!.id}'
      : widget.page.basePath;

  @override
  FormValues get values => _values;

  @override
  TextEditingController controllerFor(String key) => _controllers.putIfAbsent(
    key,
    () => TextEditingController(text: (_values[key] ?? '').toString()),
  );

  @override
  void set(String key, Object? value) {
    setState(() {
      _values[key] = value;
      _serverErrors.remove(key);
    });
    _guard.dirty = _dirty;
  }

  @override
  String? serverError(String key) => _serverErrors[key];

  @override
  void dispose() {
    _guard.dirty = false;
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _serverErrors = {});
    if (!_formKey.currentState!.validate()) {
      showMessage(
        context,
        'Исправьте ошибки, отмеченные под полями',
        error: true,
      );
      return;
    }

    final controller = context.read<EntityFormController<T>>();
    final refs = context.read<ReferenceDataNotifier>();
    final entity = widget.page.build(_values, widget.item);
    try {
      final saved = await controller.save(entity);
      _guard.dirty = false;
      await refs.load();
      if (!mounted) return;
      showMessage(
        context,
        _isEditing ? 'Изменения сохранены' : 'Запись создана',
      );
      context.go('${widget.page.basePath}/${saved.id}');
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() => _serverErrors = e.errors);
      _formKey.currentState!.validate();
    } on RepositoryException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _leave() async {
    if (!_dirty || await confirmDiscardChanges(context)) {
      _guard.dirty = false;
      if (mounted) context.go(_backLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<EntityFormController<T>>().saving;
    final fields = widget.page.fields(_values);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? widget.page.editTitle : widget.page.newTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            for (final field in fields) ...[
              field.build(context, this),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: saving ? null : _save,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isEditing ? 'Сохранить' : 'Создать'),
                ),
                OutlinedButton(onPressed: _leave, child: const Text('Отмена')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Диалог «уйти без сохранения?». Возвращает true, если уходим.
Future<bool> confirmDiscardChanges(BuildContext context) => confirmAction(
  context,
  title: 'Уйти без сохранения?',
  message:
      'В форме есть несохранённые изменения. Если уйти, они '
      'пропадут.',
  confirmLabel: 'Уйти',
);
