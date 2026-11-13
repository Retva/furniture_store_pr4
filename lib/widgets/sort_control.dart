import 'package:flutter/material.dart';

/// Выбор сортировки для узкого окна, где нет заголовков таблицы.
///
/// На широком окне сортируют щелчком по заголовку колонки, а у карточек
/// заголовков нет — поэтому поле и направление выбираются здесь.
class SortControl extends StatelessWidget {
  const SortControl({
    super.key,
    required this.fields,
    required this.field,
    required this.ascending,
    required this.onFieldChanged,
    required this.onDirectionToggled,
  });

  /// Поле сортировки → подпись.
  final Map<String, String> fields;
  final String field;
  final bool ascending;
  final ValueChanged<String> onFieldChanged;
  final VoidCallback onDirectionToggled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.sort, size: 20),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: fields.containsKey(field) ? field : fields.keys.first,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(10),
          items: [
            for (final entry in fields.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) {
            if (value != null) onFieldChanged(value);
          },
        ),
        IconButton(
          tooltip: ascending ? 'По возрастанию' : 'По убыванию',
          icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
          onPressed: onDirectionToggled,
        ),
      ],
    );
  }
}
