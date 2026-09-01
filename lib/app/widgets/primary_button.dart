import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:flutter/widgets.dart';

import 'app_gesture_detector.dart';

class PrimaryButton extends StatelessWidget {
  final Function? onTap;
  final String title;

  const PrimaryButton({
    Key? key,
    this.onTap,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: () => onTap?.call(),
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            colors: UIColors.primaryButtonGradient,
          ),
        ),
        child: Text(
          title,
          style: UITextStyles.buttonTitle,
        ),
      ),
    );
  }
}
