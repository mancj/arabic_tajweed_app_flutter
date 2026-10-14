// Образец звучит только при первой встрече, переживает выход без ответа и
// перезапуск, не записывает учебный результат. Подсказка открывается одним
// нажатием. Отложенный запуск звука не может попасть в запись микрофона.
import 'dart:async';
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_controller.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/play_control.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/pronunciation_exercise.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:arabic_tajweed_app/data/voice_recorder.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/plugin_mocks.dart';
import '../helpers/text_asset_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final curriculum = CurriculumLoader.merge([
    for (final asset in CurriculumLoader.defaultAssets)
      CurriculumLoader.parse(File(asset).readAsStringSync()),
  ]);
  const targets = ['alif.isolated', 'vowel.ba.fatha', 'word.kataba'];
  late ProgressDatabase database;
  late SharedPreferences storage;
  late _Audio audio;
  late _Recorder recorder;

  setUp(() async {
    mockPlatformPlugins();
    SharedPreferences.setMockInitialValues({});
    storage = await SharedPreferences.getInstance();
    Get.put(SharedPreferenceManager(storage));
    database = ProgressDatabase(NativeDatabase.memory());
    await database.appendAll([
      for (final node in curriculum.nodes)
        if (!targets.contains(node.atom.id))
          KnowledgeConfirmed(
            atomId: node.atom.id,
            sessionId: 1,
            at: DateTime(2026, 10, 12),
          ),
    ]);
    audio = _Audio();
    recorder = _Recorder(audio);
  });

  tearDown(() async {
    Get.reset();
    await database.close();
  });

  Future<LessonController> reachVoice(String id) async {
    final atom = curriculum.nodes.firstWhere((node) => node.atom.id == id).atom;
    final controller = LessonController(
      database: database,
      curriculum: curriculum,
      plan: LessonPlan(
        template: LessonTemplate.newLetter,
        newAtoms: [atom],
        reviewAtoms: const [],
        reason: 'проверка произношения',
      ),
      explanationBundle: TextAssetBundle.forCurriculum(curriculum),
      audio: audio,
      recorder: recorder,
      shapeLoader: (_) async => throw UnsupportedError('Письмо не проверяем'),
    );
    final ready = Completer<void>();
    final subscription = controller.stage.listen((stage) {
      if (stage != LessonStage.loading && !ready.isCompleted) ready.complete();
    });
    Get.put(controller);
    await ready.future.timeout(const Duration(seconds: 5));
    await subscription.cancel();
    expect(controller.loadError.value, isNull);
    for (var step = 0; step < 30; step++) {
      if (controller.stage.value == LessonStage.intro) {
        await controller.nextIntro();
      } else if (controller.card.value != null) {
        await controller.dismissCard();
      } else if (controller.current?.mode.isPronunciation == true) {
        expect(controller.current!.atom.id, id);
        return controller;
      } else {
        await controller.answerCorrectly(advance: true);
      }
    }
    throw StateError('Произношение не появилось');
  }

  for (final id in targets) {
    test('$id: образец помнится без ответа, прогресс не меняется', () async {
      var controller = await reachVoice(id);
      expect(controller.firstPronunciationExample, isTrue);
      final before = await database.readAll();
      final length = controller.totalExercises;
      await controller.playPronunciationExample(
        controller.current!,
        automatically: true,
      );
      expect(controller.autoPlayPronunciationExample, isFalse);
      expect(audio.played, hasLength(1));
      expect(await database.readAll(), hasLength(before.length));
      expect(controller.totalExercises, length);
      await Get.delete<LessonController>();
      await Get.delete<SharedPreferenceManager>();
      Get.put(SharedPreferenceManager(storage));
      audio = _Audio();
      recorder = _Recorder(audio);
      controller = await reachVoice(id);
      expect(controller.firstPronunciationExample, isFalse);
      expect(controller.autoPlayPronunciationExample, isFalse);
      expect(audio.played, isEmpty);
    });
  }

  test('прежняя ошибка произношения не возвращает первый образец', () async {
    await database.append(
      ProgressEvent(
        atomId: targets.first,
        sessionId: 2,
        at: DateTime(2026, 10, 12),
        mode: ExerciseMode.sayName,
        correct: false,
        attempt: 1,
        fastEnough: true,
      ),
    );
    final controller = await reachVoice(targets.first);
    expect(controller.firstPronunciationExample, isFalse);
    expect(controller.autoPlayPronunciationExample, isFalse);
  });

  test('микрофон ждёт остановки даже ещё запускающегося образца', () async {
    final controller = await reachVoice(targets.first);
    audio.playGate = Completer<void>();
    final playback = controller.playPronunciationExample(
      controller.current!,
      automatically: true,
    );
    final recording = controller.startRecording();
    final released = controller.stopRecording();
    expect(controller.canPlayPronunciationExample, isFalse);
    await controller.playPronunciationExample(controller.current!);
    expect(audio.played, hasLength(1));
    expect(recorder.starts, 0);
    audio.playGate!.complete();
    await Future.wait([playback, recording, released]);
    expect(recorder.starts, 1);
    expect(recorder.stops, 1);
    expect(recorder.heardExample, isFalse);
    expect(controller.pronunciation.isRecording.value, isFalse);
  });

  test('выход во время остановки образца не включает микрофон позже', () async {
    final controller = await reachVoice(targets.first);
    audio.stopGate = Completer<void>();
    final recording = controller.startRecording();
    await Future<void>.delayed(Duration.zero);
    await Get.delete<LessonController>();
    audio.stopGate!.complete();
    await recording;
    expect(recorder.starts, 0);
  });

  Future<void> mount(
    WidgetTester tester, {
    bool first = false,
    bool enabled = true,
    required VoidCallback play,
    required VoidCallback autoPlay,
    VoidCallback? presented,
  }) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(375, 812),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: PronunciationExercise(
                glyph: 'بَ',
                showExampleInitially: first,
                autoPlayExample: first,
                exampleEnabled: enabled,
                onPlayExample: play,
                onAutoPlayExample: autoPlay,
                onPresented: presented,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('выход до автозвука тоже сохраняет первую встречу', (
    tester,
  ) async {
    late LessonController controller;
    await tester.runAsync(() async {
      controller = await reachVoice(targets.first);
    });
    final exercise = controller.current!;
    await mount(
      tester,
      first: true,
      play: () => controller.playPronunciationExample(exercise),
      autoPlay: () =>
          controller.playPronunciationExample(exercise, automatically: true),
      presented: () => controller.markPronunciationPresented(exercise),
    );
    expect(audio.played, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await Get.delete<LessonController>();
      controller = await reachVoice(targets.first);
    });
    expect(controller.firstPronunciationExample, isFalse);
    expect(audio.played, isEmpty);
  });

  testWidgets('повтор раскрывает плеер и звучит одним нажатием', (
    tester,
  ) async {
    var plays = 0;
    var automatic = 0;
    await mount(tester, play: () => plays++, autoPlay: () => automatic++);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PlayControl), findsNothing);
    expect(find.text('Прочитайте этот слог вслух'), findsOneWidget);
    await tester.tap(find.text('Послушать пример'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PlayControl), findsOneWidget);
    expect(plays, 1);
    expect(automatic, 0);
    await mount(
      tester,
      enabled: false,
      play: () => plays++,
      autoPlay: () => automatic++,
    );
    await tester.tap(find.byType(PlayControl), warnIfMissed: false);
    expect(plays, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('первый автозвук отменяется при быстром включении записи', (
    tester,
  ) async {
    var automatic = 0;
    await mount(tester, first: true, play: () {}, autoPlay: () => automatic++);
    expect(find.text('Послушайте и повторите'), findsOneWidget);
    expect(find.byType(PlayControl), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await mount(
      tester,
      first: true,
      enabled: false,
      play: () {},
      autoPlay: () => automatic++,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(automatic, 0);
    await mount(tester, first: true, play: () {}, autoPlay: () => automatic++);
    await tester.pump(const Duration(seconds: 1));
    expect(automatic, 0);
  });
}

class _Audio implements LessonAudio {
  @override
  final ValueNotifier<AudioTrack> track = ValueNotifier(AudioTrack.silent);
  final played = <String?>[];
  Completer<void>? playGate;
  Completer<void>? stopGate;

  @override
  Future<void> playAsset(String? asset) async {
    played.add(asset);
    await playGate?.future;
    track.value = const AudioTrack(isPlaying: true);
  }

  @override
  Future<void> toggleAsset(String? asset) => playAsset(asset);

  @override
  Future<void> stop() async {
    await stopGate?.future;
    track.value = AudioTrack.silent;
  }

  @override
  Future<void> dispose() async {}
}

class _Recorder extends VoiceRecorder {
  _Recorder(this.audio);
  final _Audio audio;
  int starts = 0;
  int stops = 0;
  bool heardExample = false;
  @override
  final ValueNotifier<double> level = ValueNotifier(0.0);

  @override
  Future<bool> start() async {
    starts++;
    heardExample = audio.track.value.isPlaying;
    return true;
  }

  @override
  Future<File?> stop() async {
    stops++;
    return null;
  }

  @override
  void dispose() => level.dispose();
}
