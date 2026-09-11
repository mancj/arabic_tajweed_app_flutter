import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_forms_overview.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Сводная карточка должна одновременно показывать все формы, начиная
/// справа с отдельной. Иначе обзор теряет полноту или снова становится LTR.
void main() {
  testWidgets('все формы показаны в заданном порядке справа налево', (
    tester,
  ) async {
    final forms = [
      _form('isolated', 'ب', LetterForm.isolated),
      _form('final', 'ــب', LetterForm.finalForm),
      _form('initial', 'بــ', LetterForm.initial),
      _form('medial', 'ــبــ', LetterForm.medial),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 112,
            child: LetterFormsOverview(forms: forms),
          ),
        ),
      ),
    );

    for (final form in forms) {
      expect(find.text(form.form!.title), findsOneWidget);
      expect(find.text(form.display), findsOneWidget);
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
  });
}

Atom _form(String id, String display, LetterForm form) => Atom(
  id: id,
  kind: AtomKind.letterForm,
  display: display,
  letterId: 'ba',
  form: form,
);
