import 'package:arabic_tajweed_app/app/widgets/ui_kit/form_sequence_exercise.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Защищает механику режима форм: будущая правка плиток не должна вернуть
// проверку после каждого тапа, нарушить арабский порядок слотов справа налево,
// порядок их заполнения или запускать отклик цели только после исчезновения
// летящей плитки.
void main() {
  final isolated = _form('isolated', 'ب', LetterForm.isolated);
  final initial = _form('initial', 'بـ', LetterForm.initial);
  final medial = _form('medial', 'ـبـ', LetterForm.medial);
  final finalForm = _form('final', 'ـب', LetterForm.finalForm);

  test('время этапов считается от общей длительности', () {
    const motion = FormSequenceMotion(
      duration: Duration(milliseconds: 2000),
      interactionLockEnd: .35,
    );

    expect(motion.timeAt(.8), const Duration(milliseconds: 1600));
    expect(motion.durationBetween(.9, 1), const Duration(milliseconds: 200));
    expect(motion.interactionLockDuration, const Duration(milliseconds: 700));
  });

  testWidgets('позиции форм идут справа налево', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 288,
            child: FormSequenceExercise(
              options: [finalForm, isolated, initial, medial],
              onCompleted: (_) {},
            ),
          ),
        ),
      ),
    );

    final centers = LetterForm.values
        .map(
          (form) => tester
              .getCenter(find.byKey(ValueKey('form-slot-${form.name}')))
              .dx,
        )
        .toList();

    expect(
      centers,
      orderedEquals(centers.toList()..sort((a, b) => b.compareTo(a))),
    );
  });

  testWidgets('блокировка тапов заканчивается на заданной доле анимации', (
    tester,
  ) async {
    var completionCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 288,
            child: FormSequenceExercise(
              options: [finalForm, isolated, initial, medial],
              motion: const FormSequenceMotion(
                duration: Duration(milliseconds: 1000),
                interactionLockEnd: .2,
              ),
              onCompleted: (_) => completionCount++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('form-tile-final')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byKey(const ValueKey('form-tile-initial')));
    await tester.pump();
    expect(find.byKey(const ValueKey('form-flight-initial')), findsNothing);

    await tester.pump(const Duration(milliseconds: 201));
    await tester.tap(find.byKey(const ValueKey('form-tile-initial')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey('form-flight-initial')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 201));
    await tester.tap(find.byKey(const ValueKey('form-tile-medial')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 201));
    await tester.tap(find.byKey(const ValueKey('form-tile-isolated')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();
    expect(completionCount, 1);
  });

  testWidgets('слоты заполняются по очереди и проверяются после четвёртого', (
    tester,
  ) async {
    List<Atom>? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 288,
              child: FormSequenceExercise(
                options: [finalForm, isolated, initial, medial],
                motion: const FormSequenceMotion(
                  duration: Duration(milliseconds: 1000),
                  pulseStart: .8,
                ),
                onCompleted: (placed) => answer = placed,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('form-tile-final')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey('form-flight-final')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('form-flight-source-final')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('form-flight-target-final')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('form-flight-target-final')),
        matching: find.byType(RawImage),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('form-flight-source-final')),
        matching: find.byType(RawImage),
      ),
      findsOneWidget,
    );
    expect(answer, isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('form-slot-isolated')),
        matching: find.text('ـب'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('form-flight-final')),
        matching: find.byType(FadeTransition),
      ),
      findsNWidgets(4),
    );
    await tester.pump(const Duration(milliseconds: 799));
    expect(
      find.byKey(const ValueKey('form-landing-pulse-slot-0')),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const ValueKey('form-flight-final')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('form-landing-pulse-slot-0')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 50));
    final flightPulse = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('form-flight-final')),
        matching: find.byType(Transform),
      ),
    );
    expect(flightPulse.transform.storage.first, greaterThan(1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('form-flight-final')), findsNothing);
    expect(
      find.byKey(const ValueKey('form-landing-pulse-slot-0')),
      findsOneWidget,
    );
    expect(answer, isNull);

    await tester.tap(find.byKey(const ValueKey('form-tile-isolated')));
    await tester.pumpAndSettle();
    expect(answer, isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('form-slot-initial')),
        matching: find.text('ب'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('form-slot-initial')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey('form-flight-isolated')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('form-flight-source-isolated')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('form-flight-source-isolated')),
        matching: find.byType(RawImage),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('form-flight-target-isolated')),
      findsOneWidget,
    );
    expect(answer, isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('form-slot-initial')),
        matching: find.text('?'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('form-flight-target-isolated')),
        matching: find.byType(RawImage),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('form-flight-isolated')), findsNothing);
    expect(
      find.byKey(const ValueKey('form-landing-pulse-tile-isolated')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('form-tile-isolated')));
    await tester.pumpAndSettle();
    expect(answer, isNull);

    await tester.tap(find.byKey(const ValueKey('form-tile-initial')));
    await tester.pumpAndSettle();
    expect(answer, isNull);

    await tester.tap(find.byKey(const ValueKey('form-tile-medial')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 220));
    expect(answer, [finalForm, isolated, initial, medial]);
  });
}

Atom _form(String id, String display, LetterForm form) => Atom(
  id: id,
  kind: AtomKind.letterForm,
  display: display,
  letterId: 'ba',
  form: form,
);
