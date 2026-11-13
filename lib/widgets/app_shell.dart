import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../api/debug_options.dart';
import '../api/api_session.dart';
import '../core/config.dart';
import '../state/debug_settings_notifier.dart';

/// Общий каркас всех экранов: сверху панель с названием раздела, слева
/// меню разделов. На узком окне (меньше 600 пикселей) меню переезжает вниз.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const List<_Section> _sections = [
    _Section('Каталог', '/products', Icons.chair_outlined, Icons.chair),
    _Section(
      'Производители',
      '/manufacturers',
      Icons.factory_outlined,
      Icons.factory,
    ),
    _Section(
      'Категории',
      '/categories',
      Icons.category_outlined,
      Icons.category,
    ),
    _Section('Материалы', '/materials', Icons.texture_outlined, Icons.texture),
    _Section('Покупатели', '/customers', Icons.people_outline, Icons.people),
  ];

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final selected = _sectionIndex(path);
    final compact = screenSizeOf(context) == ScreenSize.compact;

    void onSelect(int index) => context.go(_sections[index].path);

    final appBar = AppBar(
      title: Text(_titleFor(path)),
      actions: const [_DebugMenu(), SizedBox(width: 8)],
    );

    if (compact) {
      return Scaffold(
        appBar: appBar,
        body: child,
        // На главной ни один раздел не выбран, а NavigationBar требует
        // выбранный пункт — подсвечиваем первый.
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected ?? 0,
          onDestinationSelected: onSelect,
          destinations: [
            for (final s in _sections)
              NavigationDestination(
                icon: Icon(s.icon),
                selectedIcon: Icon(s.selectedIcon),
                label: s.title,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 200,
            selectedIndex: selected,
            onDestinationSelected: onSelect,
            destinations: [
              for (final s in _sections)
                NavigationRailDestination(
                  icon: Icon(s.icon),
                  selectedIcon: Icon(s.selectedIcon),
                  label: Text(s.title),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  /// Какой раздел подсветить: `/products/7` относится к каталогу.
  /// `null` — главная, ни один раздел не выбран.
  static int? _sectionIndex(String location) {
    for (var i = 0; i < _sections.length; i++) {
      final path = _sections[i].path;
      if (location == path || location.startsWith('$path/')) return i;
    }
    return null;
  }

  static const Map<String, (String, String)> _titles = {
    '/products': ('Каталог мебели', 'товара'),
    '/manufacturers': ('Производители', 'производителя'),
    '/categories': ('Категории', 'категории'),
    '/materials': ('Материалы', 'материала'),
    '/customers': ('Покупатели', 'покупателя'),
  };

  static String _titleFor(String path) {
    for (final MapEntry(key: base, value: (list, of)) in _titles.entries) {
      if (path == base) return list;
      if (path == '$base/new') return 'Создание $of';
      if (path.startsWith('$base/') && path.endsWith('/edit')) {
        return 'Изменение $of';
      }
      if (path.startsWith('$base/')) return 'Карточка $of';
    }
    return 'МебельДом — мебельный магазин';
  }
}

class _Section {
  const _Section(this.title, this.path, this.icon, this.selectedIcon);

  final String title;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

/// Меню «Отладка»: медленный ответ, ошибка сервера, смена учётной записи.
/// Нужно, чтобы показать состояния загрузки и ошибки без правки кода.
class _DebugMenu extends StatelessWidget {
  const _DebugMenu();

  @override
  Widget build(BuildContext context) {
    final debug = context.watch<DebugSettingsNotifier>();
    final active = debug.slowResponses || debug.failResponses;

    return PopupMenuButton<String>(
      tooltip: 'Отладка',
      icon: Badge(
        isLabelVisible: active,
        smallSize: 8,
        child: const Icon(Icons.bug_report_outlined),
      ),
      onSelected: (value) => switch (value) {
        'slow' => debug.toggleSlow(),
        'fail' => debug.toggleFail(),
        _ => debug.switchUser(value),
      },
      itemBuilder: (context) => [
        if (debug.usesApi) ...[
          const PopupMenuItem<String>(
            enabled: false,
            child: Text('Сервер: ${AppConfig.apiBaseUrl}'),
          ),
          const PopupMenuDivider(),
          CheckedPopupMenuItem<String>(
            value: 'slow',
            checked: debug.slowResponses,
            child: const Text(
              'Медленные ответы (__delay=${DebugOptions.delayMs})',
            ),
          ),
          CheckedPopupMenuItem<String>(
            value: 'fail',
            checked: debug.failResponses,
            child: const Text(
              'Ошибка сервера (__fail=${DebugOptions.failStatus})',
            ),
          ),
          const PopupMenuDivider(),
          for (final user in ApiSession.demoAccounts.keys)
            CheckedPopupMenuItem<String>(
              value: user,
              checked: debug.username == user,
              child: Text('Учётная запись: $user'),
            ),
        ] else
          CheckedPopupMenuItem<String>(
            value: 'fail',
            checked: debug.failResponses,
            child: const Text('Имитировать сбой сети'),
          ),
      ],
    );
  }
}
