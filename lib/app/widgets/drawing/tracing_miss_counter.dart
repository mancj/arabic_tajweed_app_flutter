import 'drawing_canvas.dart';

/// Считает промахи подряд по одной части буквы. Набралось [limit] — пора
/// показать, как пишется: открыть контур и показ. Собранная часть и новая
/// буква счёт обнуляют, штрих, продвинувший часть, его не трогает.
///
/// Один и тот же счётчик у урока и у экрана «Алфавит»: правило про
/// подсказку — свойство обводки, а не конкретного экрана. См. SPEC.md §5.
class TracingMissCounter {
  TracingMissCounter({required this.limit});

  final int limit;

  int _misses = 0;
  int _partsDone = 0;

  /// Учитывает исход штриха. Возвращает true, когда промахов набралось
  /// на подсказку; счёт при этом обнуляется, чтобы не срабатывать на каждый
  /// следующий промах.
  bool register(TracingStrokeOutcome outcome) {
    switch (outcome) {
      case TracingStrokeOutcome.completed:
        _misses = 0;
        return false;
      case TracingStrokeOutcome.progressed:
        return false;
      case TracingStrokeOutcome.missed:
        _misses++;
        if (_misses < limit) return false;
        _misses = 0;
        return true;
    }
  }

  /// Сколько частей уже собрано: новая собранная часть обнуляет счёт.
  void partsDone(int completed) {
    if (completed == _partsDone) return;
    _partsDone = completed;
    _misses = 0;
  }

  void reset() {
    _misses = 0;
    _partsDone = 0;
  }
}
