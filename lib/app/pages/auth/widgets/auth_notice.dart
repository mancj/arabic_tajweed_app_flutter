import 'package:flutter/cupertino.dart';

import '../../../resources/ui_resources.dart';
import '../../../widgets/margin.dart';

/// Общее доступное сообщение для способов входа, пока они не подключены.
class AuthNotice extends StatelessWidget {
  const AuthNotice({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UIColors.primary10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UIColors.primary20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              CupertinoIcons.info_circle,
              size: 20,
              color: UIColors.studyAccent,
            ),
          ),
          const Margin.horizontal(12),
          Expanded(child: Text(message, style: UITextStyles.regular13)),
        ],
      ),
    ),
  );
}
