import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Главная: короткое описание и переходы к разделам.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Сайт мебельного магазина «МебельДом»',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Каталог мебели, производители, категории, материалы и покупатели. '
                'Все изменения сохраняются в браузере и переживают перезагрузку.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final (path, icon, label) in const [
                    ('/products', Icons.chair_outlined, 'Каталог'),
                    ('/manufacturers', Icons.factory_outlined, 'Производители'),
                    ('/categories', Icons.category_outlined, 'Категории'),
                    ('/materials', Icons.texture_outlined, 'Материалы'),
                    ('/customers', Icons.people_outline, 'Покупатели'),
                  ])
                    FilledButton.icon(
                      onPressed: () => context.go(path),
                      icon: Icon(icon),
                      label: Text(label),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
