import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Поле ввода, которое сообщает о новом значении не на каждое нажатие
/// клавиши, а через [delay] после того, как человек перестал печатать.
///
/// Без задержки каждая буква в поиске переписывала бы адрес и запускала
/// выборку: «диван» — пять запросов, из которых нужен только последний.
///
/// Значение [value] приходит из адреса. Если адрес поменялся снаружи —
/// кнопкой «назад» или переходом по ссылке, — текст в поле обновляется.
class DebouncedTextField extends StatefulWidget {
  const DebouncedTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.hint,
    this.prefixIcon,
    this.digitsOnly = false,
    this.errorText,
    this.delay = const Duration(milliseconds: 400),
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;

  /// Только цифры — для полей цены.
  final bool digitsOnly;
  final String? errorText;
  final Duration delay;

  @override
  State<DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<DebouncedTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  Timer? _timer;

  @override
  void didUpdateWidget(DebouncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Пока человек печатает (таймер ещё тикает), текст не трогаем: иначе
    // поле перезаписывалось бы старым значением из адреса прямо под курсором.
    final typing = _timer?.isActive ?? false;
    if (!typing && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    // Крестик очистки должен появиться сразу, а не через задержку.
    setState(() {});
    _timer?.cancel();
    _timer = Timer(widget.delay, () {
      // widget здесь — текущая конфигурация, а не та, что была при нажатии:
      // за время задержки экран мог перестроиться с новым запросом.
      if (mounted) widget.onChanged(text.trim());
    });
  }

  void _submitNow(String text) {
    _timer?.cancel();
    widget.onChanged(text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      onSubmitted: _submitNow,
      keyboardType: widget.digitsOnly ? TextInputType.number : null,
      inputFormatters: widget.digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: widget.label,
        hintText: widget.hint,
        errorText: widget.errorText,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Очистить',
                icon: const Icon(Icons.close),
                onPressed: () {
                  _controller.clear();
                  _submitNow('');
                },
              ),
      ),
    );
  }
}
