/// Безопасное чтение полей из JSON: отсутствующее поле, null или значение
/// другого типа не роняют разбор, а заменяются значением по умолчанию.
class JsonRead {
  const JsonRead._();

  static int integer(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static String text(Object? value, [String fallback = '']) =>
      value is String ? value : (value == null ? fallback : value.toString());

  /// Список идентификаторов. Понимает обе формы: `[1, 2]` — так связи
  /// хранятся локально и уходят на сервер, и `[{"id": 1, "name": …}]` —
  /// так сервер присылает развёрнутые объекты.
  static List<int> ids(Object? value) {
    if (value is! List) return const [];
    return value
        .map((e) => e is Map ? integer(e['id'], -1) : integer(e, -1))
        .where((e) => e > 0)
        .toList();
  }

  /// Идентификатор связанной записи: из поля `manufacturerId` или, если
  /// его нет, из вложенного объекта `manufacturer: {"id": …}`.
  static int refId(Map<String, dynamic> json, String idKey, String objectKey) {
    if (json[idKey] != null) return integer(json[idKey]);
    final nested = json[objectKey];
    return nested is Map ? integer(nested['id']) : 0;
  }

  static DateTime? date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static Map<String, dynamic>? map(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : null;
}
