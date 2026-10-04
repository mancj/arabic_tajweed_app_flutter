// Защищает выбор начальной статьи: нажатие на вторую/третью карточку
// должно открывать именно её, а свайпы и нижние вкладки — сохранять порядок темы.
// Просмотр материалов не должен засчитывать учебный прогресс.
import 'package:arabic_tajweed_app/app/pages/course/course_controller.dart';
import 'package:arabic_tajweed_app/app/pages/course/course_material_page.dart';
import 'package:arabic_tajweed_app/app/pages/course/course_path_page.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/rule_card.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/plugin_mocks.dart';

void main() {
  testWidgets('выбранная статья и свайпы сохраняют порядок темы', (
    tester,
  ) async {
    mockPlatformPlugins();
    const atoms = [
      Atom(
        id: 'concept.letter',
        kind: AtomKind.concept,
        display: 'Буква',
        label: 'Буква',
        note: 'Текст первой статьи',
      ),
      Atom(
        id: 'concept.makhraj',
        kind: AtomKind.concept,
        display: 'Звук',
        label: 'Звук',
        note: 'Текст второй статьи',
      ),
      Atom(
        id: 'concept.join',
        kind: AtomKind.concept,
        display: 'Соединение',
        label: 'Соединение',
        note: 'Текст третьей статьи',
      ),
    ];
    final curriculum = Curriculum(
      nodes: [
        for (final atom in atoms)
          CurriculumNode(atom: atom, requirement: const Always()),
      ],
      topics: const [
        Topic(
          id: 'test',
          stage: 1,
          title: 'Тестовая тема',
          requirement: Always(),
          counterOf: ['concept.letter', 'concept.makhraj', 'concept.join'],
        ),
      ],
    );
    final database = ProgressDatabase(NativeDatabase.memory());
    final controller = CourseController(
      database: database,
      curriculum: curriculum,
    );
    addTearDown(() async {
      controller.onClose();
      Get.reset();
      await database.close();
    });
    await tester.runAsync(controller.refreshBoard);
    expect(controller.loadError.value, isNull);
    final eventsBefore = await tester.runAsync(() => database.eventCount);
    await tester.pumpWidget(
      GetMaterialApp(
        home: CourseTopicPage(controller: controller, topicId: 'test'),
      ),
    );
    await tester.pumpAndSettle();

    for (final initialIndex in [1, 2]) {
      final card = find.text(atoms[initialIndex].label);
      await Scrollable.ensureVisible(tester.element(card), alignment: .4);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(CourseMaterialPage), findsOneWidget);
      final pages = find.byType(PageView);
      expect(tester.widget<PageView>(pages).controller!.page, initialIndex);
      expect(find.text(atoms[initialIndex].note).hitTestable(), findsOneWidget);
      expect(find.text('${initialIndex + 1} из 3'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Листайте карточки')).dy,
        greaterThan(450),
      );
      await tester.drag(pages, const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(pages).controller!.page, initialIndex - 1);
      await tester.drag(pages, const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(pages).controller!.page, initialIndex);
      final firstTab = find.byKey(const ValueKey('topic-note-concept.letter'));
      await tester.ensureVisible(firstTab);
      await tester.pumpAndSettle();
      await tester.tap(firstTab);
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(pages).controller!.page, 0);
      expect(find.text(atoms.first.note).hitTestable(), findsOneWidget);
      Get.back<void>();
      await tester.pumpAndSettle();
      expect(find.byType(CourseTopicPage), findsOneWidget);
    }
    expect(await tester.runAsync(() => database.eventCount), eventsBefore);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  // Внешний отступ над PageView обрезал статью ниже шапки: проверяем,
  // что отступ находится внутри скролла и текст проходит под заголовком.
  // Панель плавает над статьёй, а её высота (включая крупный шрифт и
  // безопасную область экрана) оставляет конец карточки доступным.
  testWidgets('статья прокручивается под заголовком с переключателем внизу', (
    tester,
  ) async {
    final atom = Atom(
      id: 'long-note',
      kind: AtomKind.concept,
      display: 'Статья',
      label: 'Статья',
      note: '${List.filled(100, 'Строка статьи').join('\n')}\nКонец статьи',
    );
    addTearDown(Get.reset);
    Widget buildApp(double textScale) => GetMaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(bottom: 34),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: CourseMaterialPage(atoms: [atom], initialIndex: 0),
    );
    await tester.pumpWidget(buildApp(1));
    await tester.pumpAndSettle();
    final pages = find.byType(PageView);
    expect(tester.getTopLeft(pages).dy, 0);
    expect(
      tester.getBottomLeft(pages).dy,
      tester.view.physicalSize.height / tester.view.devicePixelRatio,
    );
    final footerTab = find.byKey(const ValueKey('topic-note-long-note'));
    final footerY = tester.getTopLeft(footerTab).dy;
    expect(footerY, greaterThan(450));
    final heading = find.text('Материал блока');
    final articleTitle = find.text('Статья');
    final headingY = tester.getTopLeft(heading).dy;
    expect(tester.getTopLeft(articleTitle).dy, greaterThan(headingY));
    await tester.drag(pages, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(articleTitle).dy, lessThan(headingY));
    expect(tester.getTopLeft(heading).dy, headingY);
    expect(tester.getTopLeft(footerTab).dy, footerY);
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const PageStorageKey('note-scroll-long-note')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final navigation = find.ancestor(
      of: footerTab,
      matching: find.byType(BackdropFilter),
    );
    for (final textScale in [1.0, 1.6]) {
      await tester.pumpWidget(buildApp(textScale));
      await tester.pumpAndSettle();
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.byType(RuleCard)).dy,
        closeTo(tester.getTopLeft(navigation).dy - 24, .1),
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
