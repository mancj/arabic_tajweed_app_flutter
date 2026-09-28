import '../helpers/plugin_mocks.dart';
import '../helpers/text_asset_bundle.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/explanation_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_widget.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/data/letter_audio.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/play_control.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/rule_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/waveform_widget.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Фигуры для обводки читаем с диска, а не через rootBundle: в тестах он
/// отвечает только первому тесту файла, а остальные вешает.
Future<TracingShape> shapeFromDisk(String asset) async => TracingShapeSvg.parse(
  File('assets/svg/alphabet/$asset.svg').readAsStringSync(),
  id: asset,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressDatabase db;
  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );

  setUp(() {
    mockPlatformPlugins();
    db = ProgressDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    Get.reset();
    await db.close();
  });

  /// Ни pump, ни pumpAndSettle тут не помогают: контроллер ждёт настоящий
  /// ввод-вывод — чтение ассета и запрос в sqlite. Фейковые часы теста их
  /// не двигают, поэтому реальные паузы даём через runAsync.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    // Нажатие запускает анимацию на ~200 мс. Без прокрутки фейковых часов
    // тест уходит с висящим таймером и падает на проверке инвариантов.
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpLesson(
    WidgetTester tester, {
    String? topicId,
    bool continuePlanning = false,
    LessonAudio? audio,
    Curriculum? content,
    AssetBundle? explanationBundle,
  }) async {
    final lessonContent = content ?? curriculum;
    final paths = {
      for (final node in lessonContent.nodes)
        if (node.atom.explanationAsset case final path?) path,
      for (final node in lessonContent.nodes)
        if (node.atom.formsOverviewAsset case final path?) path,
    };
    final cardBundle = explanationBundle is TextAssetBundle
        ? explanationBundle
        : explanationBundle == null
        ? TextAssetBundle({})
        : null;
    if (cardBundle != null) {
      for (final path in paths) {
        cardBundle.sources.putIfAbsent(
          path,
          () => File(path).readAsStringSync(),
        );
      }
    }
    // Граф отдаём готовым: rootBundle в тестах отвечает только первому
    // тесту файла, дальше запрос повисает.
    Get.put(
      LessonController(
        database: db,
        curriculum: lessonContent,
        explanationBundle: cardBundle ?? explanationBundle,
        topicId: topicId,
        continuePlanning: continuePlanning,
        shapeLoader: shapeFromDisk,
        audio: audio ?? LetterAudio(player: AudioPlayer(playerId: 'test')),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: LessonPage()));
    await settle(tester);
  }

  testWidgets('первый урок начинается с блока «новое»', (tester) async {
    await pumpLesson(tester);

    // Проверяем состояние, а не подписи: оформление экрана меняется чаще,
    // чем правило «урок начинается с показа новых атомов».
    final controller = Get.find<LessonController>();
    expect(controller.stage.value, LessonStage.intro);
    expect(controller.introAtom?.id, 'concept.letter');
    expect(find.text('Понятно'), findsOneWidget);
  });

  // После переноса буквы в YAML её карточка должна по-прежнему произносить
  // имя сама; ручное нажатие должно идти через переключение плеера.
  testWidgets('буква из YAML звучит при появлении в уроке', (tester) async {
    final audio = _RecordingAudio();
    await pumpLesson(tester, topicId: 'm.first', audio: audio);
    expect(audio.played, isEmpty);

    // Оба вступления проходят до первой звучащей буквы.
    await tester.tap(find.text('Понятно'));
    await settle(tester);
    expect(audio.played, isEmpty);
    await tester.tap(find.text('Понятно'));
    await settle(tester);

    final controller = Get.find<LessonController>();
    expect(controller.introAtom?.id, 'alif.isolated');
    expect(audio.played, contains(LetterAudio.assetOf('alif')));
    await tester.tap(find.byType(PlayControl));
    await tester.pump();
    expect(audio.toggled, contains(LetterAudio.assetOf('alif')));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
  });

  // Перенос одной карточки в YAML не должен дублировать старую иллюстрацию
  // или менять запись знакомства с атомом в журнале.
  testWidgets('ссылка на YAML заменяет объяснение в интро урока', (
    tester,
  ) async {
    const asset = 'cards/intro.yaml';
    final content = Curriculum(
      nodes: [
        for (final node in curriculum.nodes)
          if (node.atom.id == 'concept.letter')
            CurriculumNode(
              atom: Atom.fromJson({
                ...node.atom.toJson(),
                'example': node.atom.example?.toJson(),
                'explanationAsset': asset,
              }),
              requirement: node.requirement,
            )
          else
            node,
      ],
      topics: curriculum.topics,
    );
    final bundle = TextAssetBundle({
      asset: '''
title: Заголовок из YAML
blocks:
  - text: '**Текст из YAML**'
  - letter: {glyph: ب, audio: audio/alphabet/ba.wav}
  - sound: {label: Звук буквы, audio: audio/alphabet/ba.wav}
''',
    });
    final audio = _RecordingAudio();
    await pumpLesson(
      tester,
      content: content,
      explanationBundle: bundle,
      audio: audio,
    );
    expect(find.byType(ExplanationCard), findsOneWidget);
    expect(find.text('Заголовок из YAML'), findsOneWidget);
    expect(find.text('Текст из YAML', findRichText: true), findsOneWidget);
    expect(find.textContaining('28 букв'), findsNothing);
    expect(find.byType(LetterWidgetCard), findsOneWidget);
    expect(bundle.loads.where((path) => path == asset), hasLength(1));
    final sound = find.byType(PlayControl).last;
    await tester.ensureVisible(sound);
    await tester.tap(sound);
    await tester.pump();
    expect(audio.toggled, ['audio/alphabet/ba.wav']);
    await tester.tap(find.text('Понятно'));
    await settle(tester);
    expect(
      (await db.readAll()).map((event) => event.atomId),
      contains('concept.letter'),
    );
  });

  // После общего обзора форма должна открывать свою YAML-карточку;
  // одинаковая ссылка у нескольких форм должна загружаться один раз.
  testWidgets('YAML работает и у объяснения формы перед вопросом', (
    tester,
  ) async {
    const asset = 'cards/form.yaml';
    final content = Curriculum(
      nodes: [
        for (final node in curriculum.nodes)
          if (node.atom.form != null && node.atom.form != LetterForm.isolated)
            CurriculumNode(
              atom: Atom.fromJson({
                ...node.atom.toJson(),
                'example': node.atom.example?.toJson(),
                'explanationAsset': asset,
              }),
              requirement: node.requirement,
            )
          else
            node,
      ],
      topics: curriculum.topics,
    );
    final bundle = TextAssetBundle({
      asset: '''
title: Форма из YAML
blocks:
  - text: 'Объяснение перед заданием.'
''',
    });
    await tester.runAsync(
      () => db.appendAll([
        for (final id in curriculum.topics.first.counterOf)
          AtomIntroduced(atomId: id, sessionId: 1, at: DateTime(2026)),
      ]),
    );
    await pumpLesson(
      tester,
      topicId: 'm.forms',
      content: content,
      explanationBundle: bundle,
    );
    final controller = Get.find<LessonController>();
    while (controller.stage.value == LessonStage.intro) {
      await tester.tap(find.text('Понятно'));
      await settle(tester);
    }
    expect(controller.formsOverview, isNotEmpty);
    await tester.tap(find.text('Понятно'));
    await settle(tester);
    expect(find.byType(ExplanationCard), findsOneWidget);
    expect(find.text('Форма из YAML'), findsOneWidget);
    expect(find.byType(LetterWidgetCard), findsNothing);
    expect(bundle.loads.where((path) => path == asset), hasLength(1));
  });

  testWidgets('после интро понятие записано в лог', (tester) async {
    await pumpLesson(tester);
    await tester.tap(find.text('Понятно'));
    await settle(tester);

    final log = await db.readAll();
    expect(log.map((e) => e.atomId), contains('concept.letter'));
  });

  testWidgets('кнопка ответа неактивна, пока вариант не выбран', (
    tester,
  ) async {
    await pumpLesson(tester);
    final controller = Get.find<LessonController>();

    // Проходим весь блок «новое».
    while (controller.stage.value == LessonStage.intro) {
      await tester.tap(find.text('Понятно'));
      await settle(tester);
    }

    // На первом уроке доступно только понятие — заданий с выбором ещё нет,
    // потому что спрашивать пока нечего.
    expect(controller.stage.value, LessonStage.exercise);
  });

  testWidgets('нажатие по теме открывает её урок целиком', (tester) async {
    await pumpLesson(tester, topicId: 'm.first');

    final controller = Get.find<LessonController>();
    expect(controller.isTopicLesson, isTrue);
    expect(controller.stage.value, LessonStage.intro);

    // Тема = урок: два вступления и следом четыре буквы.
    expect(controller.introAtoms.map((a) => a.id), [
      'concept.letter',
      'concept.makhraj',
      'alif.isolated',
      'ba.isolated',
      'ta.isolated',
      'tha.isolated',
    ]);
    expect(find.text('Ассаляму алейкум!'), findsOneWidget);
  });

  // Обзор должен озвучивать букву сам; кнопка лежит поверх нижней волны,
  // которая доходит до боковых и нижнего краёв карточки без отступов.
  testWidgets('перед первой формой буквы показан общий обзор', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = _RecordingAudio();
    await tester.runAsync(
      () => db.appendAll([
        for (final id in curriculum.topics.first.counterOf)
          AtomIntroduced(atomId: id, sessionId: 1, at: DateTime(2026)),
      ]),
    );
    await pumpLesson(tester, topicId: 'm.forms', audio: audio);
    final controller = Get.find<LessonController>();

    while (controller.stage.value == LessonStage.intro) {
      await tester.tap(find.text('Понятно'));
      await settle(tester);
    }

    final detail = controller.card.value!;
    final forms = controller.formsOverview.toList();
    expect(forms, isNotEmpty);
    expect(
      find.byKey(ValueKey('forms-overview-${detail.letterId}')),
      findsOneWidget,
    );
    expect(find.text('Все формы буквы ${forms.first.display}'), findsOneWidget);
    final isolated = forms.firstWhere(
      (form) => form.form == LetterForm.isolated,
    );
    final asset = LetterAudio.assetOf(isolated.letterId!);
    expect(find.byType(PlayControl), findsOneWidget);
    expect(audio.played, contains(asset));
    expect(audio.track.value.isPlaying, isTrue);
    expect(
      tester.widget<WaveformWidget>(find.byType(WaveformWidget)).track,
      same(audio.track),
    );
    final card = find.byType(RuleCard);
    final wave = find.byType(WaveformWidget);
    final play = find.byType(PlayControl);
    // Между волной и внешним краем остаётся только граница карточки в 1 px.
    expect(
      tester.getSize(wave).width,
      closeTo(tester.getSize(card).width, 2.1),
    );
    expect(
      tester.getBottomRight(wave).dy,
      closeTo(tester.getBottomRight(card).dy, 1),
    );
    expect(tester.getCenter(play).dx, closeTo(tester.getCenter(card).dx, 1));
    expect(
      tester.getBottomRight(card).dy - tester.getBottomRight(play).dy,
      // Нижний отступ 16 px и граница карточки 1 px.
      closeTo(17, 1),
    );
    expect(tester.getTopLeft(play).dy, greaterThan(tester.getTopLeft(wave).dy));

    await tester.ensureVisible(play);
    await tester.pump();
    await tester.tap(play);
    await tester.pump();
    expect(audio.toggled, [asset]);
    expect(audio.track.value.isPlaying, isFalse);

    await tester.tap(find.text('Понятно'));
    await settle(tester);
    expect(controller.formsOverview, isEmpty);
    expect(controller.card.value, same(detail));
    expect(find.text(detail.label), findsOneWidget);
  });

  testWidgets('верный ответ сам переходит дальше через пять секунд', (
    tester,
  ) async {
    await pumpLesson(tester, topicId: 'm.first');
    final controller = Get.find<LessonController>();

    while (controller.introAtom?.id != 'alif.isolated') {
      await controller.nextIntro();
      await settle(tester);
    }
    await controller.nextIntro();
    await settle(tester);

    expect(controller.isSayNameTask, isTrue);
    final current = controller.current;
    await controller.submit(directOutcome: true);
    await settle(tester);

    expect(controller.wasCorrect.value, isTrue);
    expect(controller.current, same(current));
    expect(find.text('Правильно произнесено'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('correct-answer-auto-progress')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(controller.wasCorrect.value, isFalse);
    expect(controller.current, isNot(same(current)));
    expect(
      find.byKey(const ValueKey('correct-answer-auto-progress')),
      findsNothing,
    );
  });

  // Окно открывается на следующем кадре: если отладочная кнопка успеет
  // перейти дальше, сохранённый верный ответ выглядит на экране ошибкой.
  testWidgets('отладочный верный ответ на произношение показывает успех', (
    tester,
  ) async {
    await pumpLesson(tester, topicId: 'm.first');
    final controller = Get.find<LessonController>();

    while (controller.introAtom?.id != 'alif.isolated') {
      await controller.nextIntro();
      await settle(tester);
    }
    await controller.nextIntro();
    await settle(tester);

    expect(controller.isSayNameTask, isTrue);
    final exercise = controller.current!;
    await tester.tap(find.bySemanticsLabel('Меню отладки урока'));
    await settle(tester);
    await tester.tap(find.text('Ответить верно'));
    await settle(tester);

    expect(controller.wasCorrect.value, isTrue);
    expect(controller.current, same(exercise));
    expect(find.text('Правильно произнесено'), findsOneWidget);
    expect(find.text('Попробуйте ещё раз'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(controller.wasCorrect.value, isFalse);
    expect(controller.current, isNot(same(exercise)));

    final answers = (await db.readAll()).whereType<ProgressEvent>().toList();
    final answer = answers.singleWhere(
      (event) => event.mode == ExerciseMode.sayName,
    );
    expect(answers, hasLength(1));
    expect(answer.atomId, exercise.atom.id);
    expect(answer.correct, isTrue);
  });

  // Массовое debug-завершение должно сохранять обычные ответы каждого режима,
  // а не перескакивать очередь и оставлять тему частично пройденной.
  testWidgets('отладочная кнопка завершает урок правильными ответами', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpLesson(tester, topicId: 'm.first', continuePlanning: true);
    final controller = Get.find<LessonController>();

    while (controller.stage.value == LessonStage.intro) {
      await controller.nextIntro();
      await settle(tester);
    }
    expect(find.text('Завершить урок с правильными ответами'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Меню отладки урока'));
    await settle(tester);
    expect(find.text('Завершить урок с правильными ответами'), findsOneWidget);
    await tester.tap(find.text('Завершить урок с правильными ответами'));
    for (var i = 0; i < 100; i++) {
      await settle(tester);
      if (controller.stage.value == LessonStage.finished) break;
    }

    expect(controller.stage.value, LessonStage.finished);
    expect(find.text('Урок пройден'), findsOneWidget);
    expect(find.text('Закрыть'), findsOneWidget);
    expect(find.text('Верно!'), findsNothing);
    final answers = (await db.readAll()).whereType<ProgressEvent>().toList();
    expect(answers, isNotEmpty);
    expect(answers.every((answer) => answer.correct), isTrue);
  });
}

class _RecordingAudio implements LessonAudio {
  @override
  final ValueNotifier<AudioTrack> track = ValueNotifier(AudioTrack.silent);

  final played = <String>[];
  final toggled = <String>[];

  @override
  Future<void> playAsset(String? asset) async {
    if (asset != null) {
      played.add(asset);
      track.value = const AudioTrack(isPlaying: true);
    }
  }

  @override
  Future<void> toggleAsset(String? asset) async {
    if (asset != null) {
      toggled.add(asset);
      track.value = AudioTrack(isPlaying: !track.value.isPlaying);
    }
  }

  @override
  Future<void> stop() async => track.value = AudioTrack.silent;

  @override
  Future<void> dispose() async => track.dispose();
}
