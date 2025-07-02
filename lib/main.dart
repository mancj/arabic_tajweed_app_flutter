import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:my_app_template/app/app_binding.dart';
import 'package:my_app_template/app/pages/home/home_page.dart';
import 'package:my_app_template/app/pages/splash/splash_screen_page.dart';

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
        fontFamily: "Gilroy",
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
      ],
      // home: BpmMeasureTestPage(),
    );
  }
}
