import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/validators.dart';

typedef FormValues = Map<String, Object?>;

/// То, что общая форма даёт описаниям полей: текущие значения, контроллеры
/// текстовых полей и ошибки, пришедшие из хранилища (уникальность).
abstract interface class FormScope {
  FormValues get values;
  TextEditingController controllerFor(String key);
  void set(String key, Object? value);
  String? serverError(String key);
}

/// Описание одного поля формы. Форма строится из списка таких описаний,
/// а разметка, проверка и отправка общие для всех сущностей.
abstract class FieldSpec {
  const FieldSpec();

  Widget build(BuildContext context, FormScope scope);
}

class TextFieldSpec extends FieldSpec {
  const TextFieldSpec({
    required this.name,
    required this.label,
    this.validator,
    this.hint,
    this.digitsOnly = false,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String name;
  final String label;
  final Validator? validator;
  final String? hint;
  final bool digitsOnly;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context, FormScope scope) {
    return TextFormField(
      controller: scope.controllerFor(name),
      maxLines: maxLines,
      keyboardType: digitsOnly
          ? TextInputType.number
          : (keyboardType ?? TextInputType.text),
      inputFormatters: digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: (value) => validator?.call(value) ?? scope.serverError(name),
      onChanged: (text) => scope.set(name, text),
    );
  }
}

/// Выпадающий список — связь «многие к одному». Значение — идентификатор
/// или строка, а не объект: объекты без переопределённого == перестали бы
/// совпадать с элементами списка после перезагрузки справочника.
class DropdownFieldSpec<T> extends FieldSpec {
  const DropdownFieldSpec({
    required this.name,
    required this.label,
    required this.options,
    this.requiredMessage,
    this.onSelected,
  });

  final String name;
  final String label;
  final Map<T, String> options;

  /// Если задан, пустой выбор — ошибка с этим текстом.
  final String? requiredMessage;

  /// Дополнительное действие при выборе: так делается каскад, когда
  /// выбор в одном поле сужает список другого.
  final void Function(FormScope scope, T? value)? onSelected;

  @override
  Widget build(BuildContext context, FormScope scope) {
    final raw = scope.values[name];
    final value = raw is T && options.containsKey(raw) ? raw : null;
    return DropdownButtonFormField<T>(
      key: ValueKey('$name-$value-${options.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final entry in options.entries)
          DropdownMenuItem<T>(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      validator: (selected) {
        if (selected == null && requiredMessage != null) return requiredMessage;
        return scope.serverError(name);
      },
      onChanged: (selected) {
        scope.set(name, selected);
        onSelected?.call(scope, selected);
      },
    );
  }
}

/// Множественный выбор набором FilterChip — связь «многие ко многим».
/// Обёрнут в FormField, поэтому участвует в общей проверке формы.
class MultiSelectFieldSpec extends FieldSpec {
  const MultiSelectFieldSpec({
    required this.name,
    required this.label,
    required this.options,
    this.minCount = 0,
    this.emptyText = 'Нет доступных значений',
  });

  final String name;
  final String label;
  final Map<int, String> options;
  final int minCount;
  final String emptyText;

  @override
  Widget build(BuildContext context, FormScope scope) {
    final current = [
      for (final id in (scope.values[name] as List<int>? ?? const <int>[]))
        if (options.containsKey(id)) id,
    ];
    return FormField<List<int>>(
      // Ключ зависит от набора вариантов: когда каскад меняет список,
      // поле создаётся заново с отфильтрованным значением.
      key: ValueKey('$name-${options.keys.join(',')}'),
      initialValue: current,
      validator: (value) {
        if ((value?.length ?? 0) < minCount) {
          return minCount == 1
              ? 'Выберите хотя бы одно значение'
              : 'Выберите не меньше $minCount';
        }
        return scope.serverError(name);
      },
      builder: (field) => InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          errorText: field.errorText,
        ),
        child: options.isEmpty
            ? Text(emptyText)
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in options.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: field.value!.contains(entry.key),
                      onSelected: (selected) {
                        final next = [...field.value!];
                        selected ? next.add(entry.key) : next.remove(entry.key);
                        field.didChange(next);
                        scope.set(name, next);
                      },
                    ),
                ],
              ),
      ),
    );
  }
}

class SwitchFieldSpec extends FieldSpec {
  const SwitchFieldSpec({required this.name, required this.label});

  final String name;
  final String label;

  @override
  Widget build(BuildContext context, FormScope scope) {
    return Row(
      children: [
        Switch(
          value: scope.values[name] == true,
          onChanged: (value) => scope.set(name, value),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    );
  }
}

/// Группа полей в рамке с заголовком — вложенная запись при связи
/// «один к одному» (дисконтная карта покупателя).
class SectionSpec extends FieldSpec {
  const SectionSpec({required this.title, required this.children});

  final String title;
  final List<FieldSpec> children;

  @override
  Widget build(BuildContext context, FormScope scope) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: title,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            children[i].build(context, scope),
          ],
        ],
      ),
    );
  }
}

/// Несколько полей в строку. На узкой форме встают друг под другом.
class RowSpec extends FieldSpec {
  const RowSpec(this.children);

  final List<FieldSpec> children;

  @override
  Widget build(BuildContext context, FormScope scope) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                children[i].build(context, scope),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: children[i].build(context, scope)),
            ],
          ],
        );
      },
    );
  }
}
