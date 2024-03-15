import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:gowalk_flutter_app/app/app_binding.dart';
import 'package:gowalk_flutter_app/app/pages/splash/splash_screen_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import 'app/pages/onboarding/analyzing_page/onboarding_analyzing_page.dart';
import 'app/pages/onboarding/features_page/onboarding_features_page.dart';
import 'app/pages/onboarding/questions_page/onboarding_page.dart';

var logger = Logger(
  printer: PrettyPrinter(
    colors: false,
    methodCount: 1,
    lineLength: 200,
    noBoxingByDefault: true,
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const fatalError = true;

  if (!kDebugMode) {
    // Firebase Crashlytics
    // Non-async exceptions
    FlutterError.onError = (errorDetails) {
      if (fatalError) {
        // If you want to record a "fatal" exception
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
        // ignore: dead_code
      } else {
        // If you want to record a "non-fatal" exception
        FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
      }
    };
    // Async exceptions
    PlatformDispatcher.instance.onError = (error, stack) {
      if (fatalError) {
        // If you want to record a "fatal" exception
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        // ignore: dead_code
      } else {
        // If you want to record a "non-fatal" exception
        FirebaseCrashlytics.instance.recordError(error, stack);
      }
      return true;
    };
  }

  await AppBinding().asyncDependencies();
  runApp(const MyApp());
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
        fontFamily: "PlusJakartaSans",
        useMaterial3: true,
      ),
      initialRoute: SplashScreenPage.routeName,
      initialBinding: AppBinding(),
      getPages: [
        GetPage(
          name: SplashScreenPage.routeName,
          page: () => const SplashScreenPage(),
          binding: SplashScreenBinding(),
        ),
        GetPage(
          name: HomePage.routeName,
          page: () => const HomePage(),
          binding: HomePageBinding(),
        ),
        GetPage(
          name: OnboardingPage.routeName,
          page: () => const OnboardingPage(),
          binding: OnboardingBinding(),
        ),
        GetPage(
          name: OnboardingAnalyzingPage.routeName,
          page: () => const OnboardingAnalyzingPage(),
          binding: OnboardingAnalyzingBinding(),
        ),
        GetPage(
          name: OnboardingFeaturesPage.routeName,
          page: () => const OnboardingFeaturesPage(),
          binding: OnboardingFeaturesBinding(),
        ),
      ],
      // home: BpmMeasureTestPage(),
    );
  }
}
