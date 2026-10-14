import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:flutter/material.dart';

class DebugMenuGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const DebugMenuGroup({this.title, required this.children, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Semantics(
              header: true,
              child: Text(title!, style: UITextStyles.semibold17),
            ),
          ),
          const Margin.vertical(12),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: ColoredBox(
            color: UIColors.cardBackground,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 80, right: 24),
                      color: UIColors.pageBackground,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DebugMenuIcon extends StatelessWidget {
  final IconData icon;
  final bool prominent;
  final bool destructive;

  const DebugMenuIcon({
    required this.icon,
    this.prominent = false,
    this.destructive = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? UIColors.error : UIColors.primary;
    return Container(
      width: prominent ? 48 : 40,
      height: prominent ? 48 : 40,
      decoration: BoxDecoration(
        color: destructive
            ? UIColors.error.withValues(alpha: .1)
            : UIColors.primary10,
        borderRadius: BorderRadius.circular(prominent ? 16 : 12),
      ),
      child: Icon(icon, size: prominent ? 24 : 20, color: color),
    );
  }
}

class DebugMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const DebugMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      hint: subtitle,
      excludeSemantics: true,
      onTap: onTap,
      child: AppGestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              DebugMenuIcon(icon: icon, destructive: destructive),
              const Margin.horizontal(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: UITextStyles.semibold15.copyWith(
                        color: destructive ? UIColors.error : UIColors.text,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const Margin.vertical(4),
                      Text(
                        subtitle!,
                        style: UITextStyles.regular12.copyWith(
                          color: UIColors.secondary2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Margin.horizontal(8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: UIColors.secondary2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
