import 'package:flutter/material.dart';

/// Таблица «название — значение» для карточки записи.
///
/// Раскладку выбирает LayoutBuilder, а не MediaQuery: таблица лежит внутри
/// карточки, и решать нужно по ширине карточки, а не всего окна. В узкой
/// карточке подпись стоит над значением, в широкой — слева от него.
class InfoTable extends StatelessWidget {
  const InfoTable({super.key, required this.rows});

  final List<(String, Widget)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 420;
        return Column(
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: labelStyle),
                          const SizedBox(height: 2),
                          value,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 160,
                            child: Text(label, style: labelStyle),
                          ),
                          Expanded(child: value),
                        ],
                      ),
              ),
          ],
        );
      },
    );
  }
}

/// Значение-ссылка внутри таблицы: щелчок ведёт на другой экран.
class InfoLink extends StatelessWidget {
  const InfoLink({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          style: TextStyle(
            color: scheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: scheme.primary,
          ),
        ),
      ),
    );
  }
}
