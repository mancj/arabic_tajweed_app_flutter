import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:arabic_tajweed_app/app/app_binding.dart';
import 'package:arabic_tajweed_app/app/pages/alphabet_letter/alphabet_letter_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/home/home_page.dart';
import 'package:arabic_tajweed_app/app/pages/splash/splash_screen_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const fatalError = true;


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
          name: DebugPage.routeName,
          page: () => const DebugPage(),
          binding: DebugPageBinding(),
        ),
        GetPage(
          name: AlphabetLetterPage.routeName,
          page: () => const AlphabetLetterPage(),
          binding: AlphabetLetterBinding(),
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
