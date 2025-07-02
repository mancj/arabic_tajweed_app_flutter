import 'package:my_app_template/app/resources/ui_resources.dart';
import 'package:flutter/widgets.dart';

class PageTitle extends StatelessWidget {
  final String title;

  const PageTitle(this.title, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        "Flutter App",
        style: UITextStyles.pageTitle,
        textAlign: TextAlign.center,
      ),
    );
  }
}
