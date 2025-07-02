import 'package:my_app_template/app/resources/ui_resources.dart';
import 'package:my_app_template/app/widgets/page_title.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'home_page_controller.dart';

export 'home_page_binding.dart';
export 'home_page_controller.dart';

class HomePage extends GetView<HomeController> {
  static const routeName = '/home';

  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: UIColors.pageBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageTitle('Flutter app'),
          ],
        ),
      ),
    );
  }
}
