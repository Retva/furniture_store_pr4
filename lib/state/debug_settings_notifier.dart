import 'package:flutter/foundation.dart';

import '../api/api_session.dart';
import '../api/debug_options.dart';
import '../repositories/network_simulator.dart';

/// Учебное меню «Отладка» в шапке приложения.
/// При работе с сервером включает служебные параметры мок-сервера (`__delay`, `__fail`) и переключает учётную запись, чтобы показать ответ 403.
class DebugSettingsNotifier extends ChangeNotifier {
  DebugSettingsNotifier({this.options, this.session, this.simulator});

  final DebugOptions? options;
  final ApiSession? session;
  final NetworkSimulator? simulator;

  bool get usesApi => options != null;

  bool get slowResponses => options?.slowResponses ?? false;
  bool get failResponses =>
      options?.failResponses ?? simulator?.failRequests ?? false;

  String? get username => session?.username;

  void toggleSlow() {
    final o = options;
    if (o != null) o.slowResponses = !o.slowResponses;
    notifyListeners();
  }

  void toggleFail() {
    final o = options;
    if (o != null) {
      o.failResponses = !o.failResponses;
    } else if (simulator != null) {
      simulator!.failRequests = !simulator!.failRequests;
    }
    notifyListeners();
  }

  void switchUser(String username) {
    session?.switchUser(username);
    notifyListeners();
  }
}
