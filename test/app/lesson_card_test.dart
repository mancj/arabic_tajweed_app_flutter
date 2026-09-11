import 'package:arabic_tajweed_app/app/widgets/ui_kit/lesson_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Волна в карточке обводки доходит до внешнего края LessonCard. Этот тест
// не даёт убрать обрезку и снова выпустить её за скруглённые углы карточки.
void main() {
  testWidgets('содержимое обрезается по форме карточки', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonCard(
            badge: 'Задание',
            title: 'Напишите букву',
            child: SizedBox(height: 100),
          ),
        ),
      ),
    );

    final cardContainer = tester.widget<Container>(
      find.descendant(
        of: find.byType(LessonCard),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.padding == const EdgeInsets.all(16) &&
              widget.decoration is ShapeDecoration,
        ),
      ),
    );
    expect(cardContainer.clipBehavior, Clip.antiAlias);
  });
}
