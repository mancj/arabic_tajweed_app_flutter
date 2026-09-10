import 'package:arabic_tajweed_app/app/resources/ui_text_styles.dart';
import 'package:arabic_tajweed_app/app/resources/ui_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:arabic_tajweed_app/app/app_binding.dart';
import 'package:arabic_tajweed_app/app/widgets/app_haptics.dart';
import 'package:arabic_tajweed_app/app/pages/alphabet_letter/alphabet_letter_page.dart';
import 'package:arabic_tajweed_app/app/pages/app_widgets/app_widgets_page.dart';
import 'package:arabic_tajweed_app/app/pages/atom_progress/atom_progress_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/course/course_page.dart';
import 'package:arabic_tajweed_app/app/pages/tracing/tracing_page.dart';
import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';
import 'package:arabic_tajweed_app/app/pages/pronunciation/pronunciation_page.dart';
import 'package:arabic_tajweed_app/app/pages/splash/splash_screen_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppHaptics.init();

  await AppBinding().asyncDependencies();
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
    return GetMaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: UITextStyles.fontOnest,
        scaffoldBackgroundColor: UIColors.pageBackground,
        colorScheme: ColorScheme.light(
          primary: UIColors.primary,
          onPrimary: UIColors.highlightArea,
          secondary: UIColors.secondary1,
          onSecondary: UIColors.text,
          surface: UIColors.cardBackground,
          onSurface: UIColors.text,
          outline: UIColors.borders,
          error: UIColors.secondary2,
          onError: UIColors.highlightArea,
        ),
      ),
      initialRoute: SplashScreenPage.routeName,
      initialBinding: AppBinding(),
      getPages: [
        GetPage(
          name: CoursePage.routeName,
          page: () => const CoursePage(),
          binding: CourseBinding(),
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
      ],
      // home: BpmMeasureTestPage(),
    );
  }
}
