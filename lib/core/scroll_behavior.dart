import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Разрешает прокрутку перетаскиванием мышью.
/// По умолчанию Flutter не даёт тянуть содержимое мышью. На вертикальном
/// списке это незаметно — работает колесо, а вот широкую таблицу, которая
/// не поместилась в окно, без этого вбок не сдвинуть.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
