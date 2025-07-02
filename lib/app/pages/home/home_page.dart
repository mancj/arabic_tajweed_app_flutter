import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:my_app_template/app/resources/ui_resources.dart';
import 'package:my_app_template/app/widgets/margin.dart';
import 'package:my_app_template/app/widgets/app_gesture_detector.dart';
import 'package:my_app_template/app/widgets/ui_kit/squircle_container.dart';

import 'home_page_controller.dart';

export 'home_page_binding.dart';
export 'home_page_controller.dart';

class HomePage extends GetView<HomeController> {
  static const routeName = '/home';

  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIColors.pageBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: RichText(
                textAlign: TextAlign.start,
                text: const TextSpan(children: [
                  TextSpan(
                    text: 'Арабский\n',
                    style: UITextStyles.pageTitleSemibold,
                  ),
                  TextSpan(
                    text: 'словарь',
                    style: UITextStyles.pageTitle,
                  ),
                ]),
              ),
            ),
            _searchBar(),
          ],
        ),
      ),
    );
  }

  Container _searchBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      height: 48,
      child: SquircleContainer(
        child: AppGestureDetector(
          child: Container(
            padding: const EdgeInsets.only(left: 12, right: 16),
            child: Row(
              children: [
                SvgPicture.asset(UISVGAssets.search),
                const Margin.horizontal(16),
                RichText(
                  text: const TextSpan(
                    style: UITextStyles.regular17,
                    children: [
                      TextSpan(
                        text: 'Нажмите',
                        style: UITextStyles.semibold17,
                      ),
                      TextSpan(text: ' для поиска'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
