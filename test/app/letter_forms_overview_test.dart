import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_forms_overview.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/highlighted_word.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Сводная карточка должна одновременно показывать все формы и реальные
/// соединения в словах. Без примеров абстрактные глифы не объясняют форму.
void main() {
  testWidgets('все формы показаны в заданном порядке справа налево', (
    tester,
  ) async {
    final forms = [
      _form('isolated', 'ب', LetterForm.isolated),
      _form(
        'initial',
        'بــ',
        LetterForm.initial,
        example: const WordExample(word: 'بات', index: 0),
      ),
      _form(
        'medial',
        'ــبــ',
        LetterForm.medial,
        example: const WordExample(word: 'ثبت', index: 1),
      ),
      _form(
        'final',
        'ــب',
        LetterForm.finalForm,
        example: const WordExample(word: 'كتب', index: 2),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 344,
            child: LetterFormsOverview(forms: forms),
          ),
        ),
      ),
    );

    for (final form in forms) {
      expect(
        find.text(form.form!.title),
        form.example == null ? findsOneWidget : findsNWidgets(2),
      );
      expect(find.text(form.display), findsOneWidget);
    }
    expect(find.text('Примеры слов'), findsOneWidget);
    expect(
      find.text(
        'Посмотрите, как буква соединяется с соседними буквами в словах:',
      ),
      findsOneWidget,
    );
    expect(find.byType(HighlightedWord), findsNWidgets(3));
    final examples = find.byKey(
      const ValueKey('letter-form-overview-examples'),
    );
    expect(examples, findsOneWidget);
    for (final form in forms.where((form) => form.example != null)) {
      final example = form.example!;
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is HighlightedWord &&
              widget.word == example.word &&
              widget.index == example.index &&
              widget.form == form.form,
        ),
        findsOneWidget,
      );
    }

    final centers = [
      for (final form in forms)
        tester.getCenter(
          find.byKey(ValueKey('letter-form-overview-${form.form!.name}')),
        ),
    ];
    expect(
      centers.map((center) => center.dx),
      orderedEquals(
        centers.map((center) => center.dx).toList()
          ..sort((a, b) => b.compareTo(a)),
      ),
    );
    final examplesTop = tester.getTopLeft(examples).dy;
    for (final form in forms) {
      expect(
        examplesTop,
        greaterThan(
          tester
              .getBottomRight(
                find.byKey(ValueKey('letter-form-overview-${form.form!.name}')),
              )
              .dy,
        ),
      );
    }
  });
}

Atom _form(
  String id,
  String display,
  LetterForm form, {
  WordExample? example,
}) => Atom(
  id: id,
  kind: AtomKind.letterForm,
  display: display,
  letterId: 'ba',
  form: form,
  example: example,
);
