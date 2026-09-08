import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_miss_counter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Правило «три промаха подряд — подсказка» одно на урок и экран «Алфавит».
void main() {
  const miss = TracingStrokeOutcome.missed;

  test('срабатывает на третьем промахе подряд и обнуляется', () {
    final counter = TracingMissCounter(limit: 3);
    expect(counter.register(miss), isFalse);
    expect(counter.register(miss), isFalse);
    expect(counter.register(miss), isTrue);
    expect(counter.register(miss), isFalse, reason: 'счёт начался заново');
  });

  test('продвинувший штрих не в счёт, собранная часть обнуляет', () {
    final counter = TracingMissCounter(limit: 3);
    counter.register(miss);
    counter.register(miss);
    expect(counter.register(TracingStrokeOutcome.progressed), isFalse);
    expect(counter.register(miss), isTrue, reason: 'фрагмент счёт не сбил');

    counter.register(miss);
    counter.register(miss);
    counter.register(TracingStrokeOutcome.completed);
    expect(counter.register(miss), isFalse, reason: 'после части счёт с нуля');
  });

  test('новая собранная часть обнуляет счёт', () {
    final counter = TracingMissCounter(limit: 3);
    counter.register(miss);
    counter.register(miss);
    counter.partsDone(1);
    expect(counter.register(miss), isFalse);
    counter.partsDone(1);
    expect(
      counter.register(miss),
      isFalse,
      reason: 'тот же прогресс не сбивает',
    );
    expect(counter.register(miss), isTrue);
  });
}
