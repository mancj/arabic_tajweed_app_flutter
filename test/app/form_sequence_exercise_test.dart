import 'package:arabic_tajweed_app/app/widgets/ui_kit/form_sequence_exercise.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Защищает механику режима форм: будущая правка плиток не должна вернуть
// проверку после каждого тапа, нарушить арабский порядок слотов справа налево,
// порядок их заполнения, потерять верные позиции между попытками, убрать
// поэтапную подсказку или запускать отклик цели только после исчезновения
// летящей плитки. Звуковые слоты также обязаны включать активную запись и
// оставлять отдельную кнопку повтора доступной после размещения плитки, не
// перекрывая ею арабскую букву.
// Повторяемые знаки не исчезают после выбора, а слоты показывают собственную
// букву со знаком, в том числе при подсказке с двумя одинаковыми ответами.
// Двухформенная версия должна показывать только отдельную и конечную
// позиции и отправлять ответ после второго выбора.
void main() {
  final isolated = _form('isolated', 'ب', LetterForm.isolated);
  final initial = _form('initial', 'بـ', LetterForm.initial);
  final medial = _form('medial', 'ـبـ', LetterForm.medial);
  final finalForm = _form('final', 'ـب', LetterForm.finalForm);

  testWidgets('двухформенная буква собирается в двух позициях', (tester) async {
    final alone = _form('alif.isolated', 'ا', LetterForm.isolated);
    final end = _form('alif.finalForm', 'ـا', LetterForm.finalForm);
    List<Atom>? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: FormSequenceExercise(
              options: [end, alone],
              motion: const FormSequenceMotion(
                duration: Duration(milliseconds: 100),
              ),
              onCompleted: (placed) => answer = placed,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Отдельно'), findsOneWidget);
    expect(find.text('В конце'), findsOneWidget);
    expect(find.text('В начале'), findsNothing);
    expect(find.text('В середине'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('form-tile-alif.isolated')));
    await tester.pumpAndSettle();
    expect(answer, isNull);
    await tester.tap(find.byKey(const ValueKey('form-tile-alif.finalForm')));
    await tester.pumpAndSettle();
    expect(answer, [alone, end]);
  });

  test('время этапов считается от общей длительности', () {
    const motion = FormSequenceMotion(
      duration: Duration(milliseconds: 2000),
      interactionLockEnd: .35,
    );

    expect(motion.timeAt(.8), const Duration(milliseconds: 1600));
    expect(motion.durationBetween(.9, 1), const Duration(milliseconds: 200));
    expect(motion.interactionLockDuration, const Duration(milliseconds: 700));
  });

  testWidgets('три звуковых слота звучат по мере заполнения', (tester) async {
    final sounds = [
      const Atom(
        id: 'ba.fatha',
        kind: AtomKind.haraka,
        display: 'بَ',
        label: 'Ба',
      ),
      const Atom(
        id: 'ba.kasra',
        kind: AtomKind.haraka,
        display: 'بِ',
        label: 'Би',
      ),
      const Atom(
        id: 'ba.damma',
        kind: AtomKind.haraka,
        display: 'بُ',
        label: 'Бу',
      ),
    ];
    final slots = [
      for (final (index, atom) in sounds.indexed)
        SequenceSlot(
          id: 'sound-$index',
          title: 'Звук ${index + 1}',
          expectedAtomId: atom.id,
          audioAsset: 'audio/$index.mp3',
        ),
    ];
    final activated = <int>[];
    final replayed = <int>[];
    List<Atom>? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: FormSequenceExercise(
              slots: slots,
              options: [sounds[2], sounds[0], sounds[1]],
              instruction: 'Послушайте и выберите огласовку',
              optionNoun: 'Огласовка',
              motion: const FormSequenceMotion(
                duration: Duration(milliseconds: 100),
              ),
              onActiveSlotChanged: activated.add,
              onPlaySlot: replayed.add,
              onCompleted: (placed) => answer = placed,
            ),
          ),
        ),
      ),
    );
    expect(activated, [0]);
    expect(find.text('Послушайте и выберите огласовку'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('form-tile-ba.fatha')));
    await tester.pumpAndSettle();
    expect(activated, [0, 1]);
    await tester.tap(find.byTooltip('Прослушать звук 1'));
    await tester.pump();
    expect(replayed, [0]);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('form-slot-sound-0')),
        matching: find.text('بَ'),
      ),
      findsOneWidget,
    );
    final firstSlot = find.byKey(const ValueKey('form-slot-sound-0'));
    final glyphRect = tester.getRect(
      find.descendant(of: firstSlot, matching: find.text('بَ')),
    );
    final playButtonRect = tester.getRect(
      find.descendant(of: firstSlot, matching: find.byType(IconButton)),
    );
    expect(glyphRect.overlaps(playButtonRect), isFalse);

    await tester.tap(find.byKey(const ValueKey('form-tile-ba.kasra')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('form-tile-ba.damma')));
    await tester.pumpAndSettle();
    expect(activated, [0, 1, 2]);
    expect(answer?.map((atom) => atom.id), [
      'ba.fatha',
      'ba.kasra',
      'ba.damma',
    ]);
  });

  testWidgets('один знак заполняет разные буквы и остаётся доступным', (
    tester,
  ) async {
    final slots = [
      for (final (index, glyph) in ['ب', 'ت', 'م'].indexed)
        SequenceSlot(
          id: 'mixed-$index',
          title: 'Звук ${index + 1}',
          expectedAtomId: index == 2 ? 'haraka.kasra' : 'haraka.fatha',
          baseGlyph: glyph,
          audioAsset: 'audio/$index.mp3',
        ),
    ];
    final activated = <int>[];
    List<Atom>? answer;
    Widget exercise({bool reveal = false}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 288,
          child: FormSequenceExercise(
            key: ValueKey(reveal),
            slots: slots,
            options: HarakaSyllables.marks,
            reusableOptions: true,
            revealCorrectOrder: reveal,
            optionNoun: 'Огласовка',
            motion: const FormSequenceMotion(
              duration: Duration(milliseconds: 100),
            ),
            onActiveSlotChanged: activated.add,
            onCompleted: (placed) => answer = placed,
          ),
        ),
      ),
    );
    await tester.pumpWidget(exercise());
    for (final glyph in ['ب', 'ت', 'م']) {
      expect(find.text(glyph), findsOneWidget);
    }
    final fatha = find.byKey(const ValueKey('form-tile-haraka.fatha'));
    await tester.tap(fatha);
    await tester.pumpAndSettle();
    expect(find.text('بَ'), findsOneWidget);
    await tester.tap(fatha);
    await tester.pumpAndSettle();
    expect(find.text('تَ'), findsOneWidget);
    expect(find.text('◌َ'), findsOneWidget);
    expect(answer, isNull);
    await tester.tap(find.byKey(const ValueKey('form-slot-mixed-0')));
    await tester.pumpAndSettle();
    expect(find.text('ب'), findsOneWidget);
    expect(find.text('تَ'), findsOneWidget);
    await tester.tap(fatha);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('form-tile-haraka.kasra')));
    await tester.pumpAndSettle();
    expect(answer?.map((a) => a.id), [
      'haraka.fatha',
      'haraka.fatha',
      'haraka.kasra',
    ]);
    expect(find.text('مِ'), findsOneWidget);
    expect(activated, [0, 1, 2, 0, 2]);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(exercise(reveal: true));
    for (final glyph in ['بَ', 'تَ', 'مِ']) {
      expect(find.text(glyph), findsOneWidget);
    }
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    for (final glyph in ['ب', 'ت', 'م']) {
      expect(find.text(glyph), findsOneWidget);
    }
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

  testWidgets('после ошибки слоты показывают правильность каждой формы', (
    tester,
  ) async {
    const exerciseKey = ValueKey('feedback-sequence');
    const results = [true, false, false, true];

    Widget exercise({List<bool>? slotResults}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 288,
          child: FormSequenceExercise(
            key: exerciseKey,
            options: [finalForm, isolated, initial, medial],
            slotResults: slotResults,
            onCompleted: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(exercise());
    for (final id in ['isolated', 'medial', 'initial', 'final']) {
      await tester.tap(find.byKey(ValueKey('form-tile-$id')));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(exercise(slotResults: results));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('form-slot-correct-isolated')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('form-slot-wrong-initial')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('form-slot-wrong-medial')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('form-slot-correct-finalForm')),
      findsOneWidget,
    );
  });

  testWidgets('верные формы закрепляются, а ошибочные собираются заново', (
    tester,
  ) async {
    List<Atom>? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 288,
            child: FormSequenceExercise(
              options: [finalForm, isolated, initial, medial],
              initialPlaced: [isolated, null, null, finalForm],
              onCompleted: (placed) => answer = placed,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('form-slot-isolated')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('form-slot-isolated')),
        matching: find.text('ب'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('form-tile-initial')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('form-tile-medial')));
    await tester.pumpAndSettle();
    expect(answer, [isolated, initial, medial, finalForm]);
  });

  testWidgets('после третьей ошибки ответ показывается и очищается', (
    tester,
  ) async {
    List<Atom>? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 288,
            child: FormSequenceExercise(
              options: [finalForm, isolated, initial, medial],
              initialPlaced: [isolated, null, null, finalForm],
              revealCorrectOrder: true,
              onCompleted: (placed) => answer = placed,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('form-answer-reveal')), findsOneWidget);
    expect(find.text('?'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(4));

    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.byKey(const ValueKey('form-answer-reveal')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const ValueKey('form-instruction')), findsOneWidget);
    expect(find.text('?'), findsNWidgets(4));

    for (final id in ['isolated', 'initial', 'medial', 'final']) {
      await tester.tap(find.byKey(ValueKey('form-tile-$id')));
      await tester.pumpAndSettle();
    }
    expect(answer, [isolated, initial, medial, finalForm]);
  });
}

Atom _form(String id, String display, LetterForm form) => Atom(
  id: id,
  kind: AtomKind.letterForm,
  display: display,
  letterId: 'ba',
  form: form,
);
