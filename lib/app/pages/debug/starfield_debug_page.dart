import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/starfield_widget.dart';
import 'package:flutter/material.dart';

/// Полноэкранный стенд анимации полёта сквозь точки.
class StarfieldDebugPage extends StatelessWidget {
  static const routeName = '/debug/starfield';

  const StarfieldDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Полёт между звёздами',
      backgroundColor: UIColors.pageBackground,
      contentPadding: EdgeInsets.zero,
      builder: (_, __) => StarfieldWidget(
        color: UIColors.white,
        maxRadius: 1,
        speed: 1,
        minRadius: .5,
      ),
    );
  }
}
