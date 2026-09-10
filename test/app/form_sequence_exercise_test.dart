import 'package:arabic_tajweed_app/app/widgets/ui_kit/form_sequence_exercise.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Защищает механику режима форм: будущая правка плиток не должна вернуть
// проверку после каждого тапа или нарушить порядок заполнения трёх слотов.
void main() {
  final initial = _form('initial', 'بـ', LetterForm.initial);
  final medial = _form('medial', 'ـبـ', LetterForm.medial);
  final finalForm = _form('final', 'ـب', LetterForm.finalForm);

  testWidgets('слоты заполняются по очереди и проверяются после третьего', (
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
                options: [finalForm, initial, medial],
                onCompleted: (placed) => answer = placed,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('form-tile-final')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(answer, isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('form-slot-initial')),
        matching: find.text('ـب'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('form-tile-initial')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(answer, isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('form-slot-medial')),
        matching: find.text('بـ'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('form-slot-medial')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(answer, isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('form-slot-medial')),
        matching: find.text('?'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('form-tile-initial')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(answer, isNull);

    await tester.tap(find.byKey(const ValueKey('form-tile-medial')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(answer, [finalForm, initial, medial]);
  });
}

Atom _form(String id, String display, LetterForm form) => Atom(
  id: id,
  kind: AtomKind.letterForm,
  display: display,
  letterId: 'ba',
  form: form,
);
