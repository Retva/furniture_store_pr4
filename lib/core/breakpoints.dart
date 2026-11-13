import 'package:flutter/widgets.dart';


enum ScreenSize { compact, medium, expanded }

class Breakpoints {
  const Breakpoints._();

  static const double medium = 600;
  static const double expanded = 1200;

  static const double readableWidth = 820;
}

ScreenSize screenSizeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < Breakpoints.medium) return ScreenSize.compact;
  if (width < Breakpoints.expanded) return ScreenSize.medium;
  return ScreenSize.expanded;
}

T byScreen<T>(
  BuildContext context, {
  required T compact,
  T? medium,
  T? expanded,
}) {
  return switch (screenSizeOf(context)) {
    ScreenSize.compact => compact,
    ScreenSize.medium => medium ?? compact,
    ScreenSize.expanded => expanded ?? medium ?? compact,
  };
}
