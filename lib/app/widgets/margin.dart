import 'package:flutter/material.dart';

class Margin extends StatelessWidget {
  final double horizontal;
  final double vertical;

  const Margin({Key? key, required this.horizontal, required this.vertical})
      : super(key: key);

  const Margin.vertical(this.vertical, {Key? key})
      : horizontal = 0,
        super(key: key);

  const Margin.horizontal(this.horizontal, {Key? key})
      : vertical = 0,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: horizontal,
      height: vertical,
    );
  }
}
