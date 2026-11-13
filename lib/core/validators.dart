/// Проверки полей форм. Каждая проверка — функция: `null`, если значение
/// подходит, и текст ошибки, если нет. Собраны в одном месте и
/// переиспользуются всеми формами.
typedef Validator = String? Function(String? value);

class V {
  const V._();

  static Validator required([String message = 'Заполните поле']) =>
      (value) => (value == null || value.trim().isEmpty) ? message : null;

  static Validator length({int min = 0, int max = 255}) => (value) {
    final text = value?.trim() ?? '';
    if (text.length < min) return 'Не короче $min символов';
    if (text.length > max) return 'Не длиннее $max символов';
    return null;
  };

  static Validator integer({int? min, int? max}) => (value) {
    final n = int.tryParse(value?.trim() ?? '');
    if (n == null) return 'Введите целое число';
    if (min != null && n < min) return 'Не меньше $min';
    if (max != null && n > max) return 'Не больше $max';
    return null;
  };

  /// Количество или цена: целое число больше нуля.
  static Validator positive({int? max}) => (value) {
    final n = int.tryParse(value?.trim() ?? '');
    if (n == null) return 'Введите целое число';
    if (n <= 0) return 'Должно быть больше нуля';
    if (max != null && n > max) return 'Не больше $max';
    return null;
  };

  /// Остаток на складе: целое число, ноль допустим.
  static Validator nonNegative({int? max}) => integer(min: 0, max: max);

  static final RegExp _email = RegExp(
    r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[a-zA-Z]{2,}$',
  );

  static Validator email() =>
      (value) => _email.hasMatch(value?.trim() ?? '')
      ? null
      : 'Некорректный адрес почты';

  /// Телефон: от 10 до 15 цифр, допускаются +, пробелы, скобки и дефисы.
  static Validator phone() => (value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\+?[\d\s()\-]+$').hasMatch(text)) {
      return 'Только цифры, +, пробелы, скобки и дефисы';
    }
    final digits = text.replaceAll(RegExp(r'\D'), '').length;
    if (digits < 10 || digits > 15) return 'В номере должно быть 10–15 цифр';
    return null;
  };

  static Validator pattern(RegExp re, String message) =>
      (value) => re.hasMatch(value?.trim() ?? '') ? null : message;

  /// Дата в виде ДД.ММ.ГГГГ, не позже сегодняшнего дня.
  static Validator pastDate() => (value) {
    final date = parseDate(value);
    if (date == null) return 'Дата в формате ДД.ММ.ГГГГ';
    if (date.isAfter(DateTime.now())) return 'Дата не может быть в будущем';
    if (date.year < 1990) return 'Не раньше 1990 года';
    return null;
  };

  /// Пустое значение допустимо, заполненное проверяется [validator].
  static Validator optional(Validator validator) =>
      (value) =>
          (value == null || value.trim().isEmpty) ? null : validator(value);

  /// Первая сработавшая проверка из списка.
  static Validator combine(List<Validator> validators) => (value) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) return error;
    }
    return null;
  };

  static DateTime? parseDate(String? value) {
    final match = RegExp(
      r'^(\d{2})\.(\d{2})\.(\d{4})$',
    ).firstMatch(value?.trim() ?? '');
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    // 31.02.2026 DateTime превратит в 3 марта — такую дату считаем неверной.
    if (date.day != day || date.month != month) return null;
    return date;
  }
}
