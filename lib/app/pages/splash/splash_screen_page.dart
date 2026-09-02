import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'splash_screen_controller.dart';
export 'splash_screen_binding.dart';

class SplashScreenPage extends GetView<SplashScreenController> {
  static const routeName = '/splash_screen';

  const SplashScreenPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center());
  }
}
