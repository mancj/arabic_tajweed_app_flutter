import 'package:arabic_tajweed_app/app/resources/ui_text_styles.dart';
import 'package:arabic_tajweed_app/app/resources/ui_colors.dart';
import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:rive/rive.dart' as rive;
import 'package:arabic_tajweed_app/app/app_binding.dart';
import 'package:arabic_tajweed_app/app/diagnostics/app_diagnostics.dart';
import 'package:arabic_tajweed_app/app/diagnostics/web_performance_probe.dart';
import 'package:arabic_tajweed_app/app/widgets/app_haptics.dart';
import 'package:arabic_tajweed_app/app/pages/alphabet_letter/alphabet_letter_page.dart';
import 'package:arabic_tajweed_app/app/pages/app_widgets/app_widgets_page.dart';
import 'package:arabic_tajweed_app/app/pages/atom_progress/atom_progress_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/connection_build_debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/word_build_debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/form_sequence_debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/glow_wave_debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/haraka_drawing_debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/haraka_match_debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/haraka_sequence_debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/orbital_rings_debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/starfield_debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/syllable_build_debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/syllable_pronunciation_debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/course/course_page.dart';
import 'package:arabic_tajweed_app/app/pages/profile/profile_page.dart';
import 'package:arabic_tajweed_app/app/pages/auth/authorization_page.dart';
import 'package:arabic_tajweed_app/app/pages/auth/email_authorization_page.dart';
import 'package:arabic_tajweed_app/app/pages/tracing/tracing_page.dart';
import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';
import 'package:arabic_tajweed_app/app/pages/pronunciation/pronunciation_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/pronunciation_exercise_debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/pronunciation_recorder_debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/splash/splash_screen_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppDiagnostics.install();

  await AppHaptics.init();
  // В браузере Factory.flutter доступна только после загрузки Rive.
  if (kIsWeb) await rive.RiveNative.init();

  await AppBinding().asyncDependencies();
  final savedColorScheme = Get.find<SharedPreferenceManager>().colorScheme
      .get();
  UIColors.selection.value = switch (savedColorScheme) {
    'light' => AppColorScheme.light,
    'dark' => AppColorScheme.dark,
    'dark2' => AppColorScheme.dark2,
    _ => AppColorScheme.system,
  };
  await LiquidGlassWidgets.initialize();
  runApp(
    LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppColorScheme>(
      valueListenable: UIColors.selection,
      builder: (context, selection, _) {
        return _buildApp(selection);
      },
    );
  }

  Widget _buildApp(AppColorScheme selection) {
    final darkPalette = selection == AppColorScheme.dark2
        ? UIColors.dark2
        : UIColors.dark;
    return GetMaterialApp(
      builder: kIsWeb && const bool.fromEnvironment('WEB_PERF_PROBE')
          ? (context, child) => WebPerformanceProbe(child: child!)
          : null,
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: UITextStyles.fontOnest,
        scaffoldBackgroundColor: UIColors.light.pageBackground,
        colorScheme: ColorScheme.light(
          primary: UIColors.light.primary,
          onPrimary: UIColors.light.highlightArea,
          secondary: UIColors.light.secondary1,
          onSecondary: UIColors.light.text,
          surface: UIColors.light.cardBackground,
          onSurface: UIColors.light.text,
          outline: UIColors.light.borders,
          error: UIColors.light.secondary2,
          onError: UIColors.light.highlightArea,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: UITextStyles.fontOnest,
        scaffoldBackgroundColor: darkPalette.pageBackground,
        colorScheme: ColorScheme.dark(
          primary: darkPalette.primary,
          onPrimary: darkPalette.highlightArea,
          secondary: darkPalette.secondary1,
          onSecondary: darkPalette.text,
          surface: darkPalette.cardBackground,
          onSurface: darkPalette.text,
          outline: darkPalette.borders,
          error: darkPalette.secondary2,
          onError: darkPalette.highlightArea,
        ),
      ),
      themeMode: switch (selection) {
        AppColorScheme.system => ThemeMode.system,
        AppColorScheme.light => ThemeMode.light,
        AppColorScheme.dark || AppColorScheme.dark2 => ThemeMode.dark,
      },
      initialRoute: SplashScreenPage.routeName,
      initialBinding: AppBinding(),
      getPages: [
        GetPage(
          name: CoursePage.routeName,
          page: () => const CoursePage(),
          binding: CourseBinding(),
        ),
        GetPage(name: ProfilePage.routeName, page: () => const ProfilePage()),
        GetPage(
          name: AuthorizationPage.routeName,
          page: () => const AuthorizationPage(),
        ),
        GetPage(
          name: EmailAuthorizationPage.routeName,
          page: () => const EmailAuthorizationPage(),
        ),
        GetPage(
          name: LessonPage.routeName,
          page: () => const LessonPage(),
          binding: LessonBinding(),
        ),
        GetPage(
          name: SplashScreenPage.routeName,
          page: () => const SplashScreenPage(),
          binding: SplashScreenBinding(),
        ),
        GetPage(
          name: DebugPage.routeName,
          page: () => const DebugPage(),
          binding: DebugPageBinding(),
        ),
        GetPage(
          name: FormSequenceDebugPage.routeName,
          page: () => const FormSequenceDebugPage(),
        ),
        GetPage(
          name: HarakaSequenceDebugPage.routeName,
          page: () => const HarakaSequenceDebugPage(),
        ),
        GetPage(
          name: HarakaDrawingDebugPage.routeName,
          page: () => const HarakaDrawingDebugPage(),
        ),
        GetPage(
          name: HarakaMatchDebugPage.routeName,
          page: () => const HarakaMatchDebugPage(),
        ),
        GetPage(
          name: SyllablePronunciationDebugPage.routeName,
          page: () => const SyllablePronunciationDebugPage(),
        ),
        GetPage(
          name: SyllableBuildDebugPage.routeName,
          page: () => const SyllableBuildDebugPage(),
        ),
        GetPage(
          name: ConnectionBuildDebugPage.routeName,
          page: () => const ConnectionBuildDebugPage(),
        ),
        GetPage(
          name: WordBuildDebugPage.routeName,
          page: () => const WordBuildDebugPage(),
        ),
        GetPage(
          name: StarfieldDebugPage.routeName,
          page: () => const StarfieldDebugPage(),
        ),
        GetPage(
          name: GlowWaveDebugPage.routeName,
          page: () => const GlowWaveDebugPage(),
        ),
        GetPage(
          name: PronunciationRecorderDebugPage.routeName,
          page: () => const PronunciationRecorderDebugPage(),
        ),
        GetPage(
          name: OrbitalRingsDebugPage.routeName,
          page: () => const OrbitalRingsDebugPage(),
        ),
        GetPage(
          name: AtomProgressPage.routeName,
          page: () => const AtomProgressPage(),
          binding: AtomProgressBinding(),
        ),
        GetPage(
          name: AlphabetLetterPage.routeName,
          page: () => const AlphabetLetterPage(),
          binding: AlphabetLetterBinding(),
        ),
        GetPage(
          name: AppWidgetsPage.routeName,
          page: () => const AppWidgetsPage(),
          binding: AppWidgetsBinding(),
        ),
        GetPage(
          name: TracingPage.routeName,
          page: () => const TracingPage(),
          binding: TracingPageBinding(),
        ),
        GetPage(
          name: PronunciationPage.routeName,
          page: () => const PronunciationPage(),
          binding: PronunciationBinding(),
        ),
        GetPage(
          name: PronunciationExerciseDebugPage.routeName,
          page: () => const PronunciationExerciseDebugPage(),
          binding: PronunciationBinding(),
        ),
      ],
      // home: BpmMeasureTestPage(),
    );
  }
}
