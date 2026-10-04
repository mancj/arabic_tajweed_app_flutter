import 'dart:ui';

import 'package:flutter/material.dart';

import '../../resources/ui_resources.dart';
import '../app_gesture_detector.dart';
import '../margin.dart';
import '../measure_height.dart';
import '../squircle_borders.dart';

typedef NotesPageBuilder =
    Widget Function(BuildContext context, int index, bool active);

/// Общий просмотр конспектов занятия и материалов темы.
class NotesPager extends StatefulWidget {
  const NotesPager({
    required this.items,
    required this.insets,
    required this.itemBuilder,
    this.initialIndex = 0,
    this.tabKeyPrefix = 'note',
    super.key,
  }) : assert(items.length > 0),
       assert(initialIndex >= 0 && initialIndex < items.length);

  final List<({String id, String title})> items;
  final EdgeInsets insets;
  final NotesPageBuilder itemBuilder;
  final int initialIndex;
  final String tabKeyPrefix;

  @override
  State<NotesPager> createState() => _NotesPagerState();
}

class _NotesPagerState extends State<NotesPager> {
  late int _selectedIndex;
  late final PageController _pageController;
  final _selectedTabKey = GlobalKey();
  double _navigationHeight = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _selectedIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSelectedTab(animate: false);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showSelectedTab({bool animate = true}) {
    final selectedContext = _selectedTabKey.currentContext;
    if (!mounted || selectedContext == null) return;
    // Показываем вкладку только по горизонтали, не возвращая статью наверх.
    Scrollable.of(selectedContext).position.ensureVisible(
      selectedContext.findRenderObject()!,
      duration: animate ? const Duration(milliseconds: 200) : Duration.zero,
      alignment: .5,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSelectedTab());
  }

  void _selectNote(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildNavigation() {
    final insets = widget.insets;
    final items = widget.items;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items.length > 1)
          Padding(
            padding: EdgeInsets.fromLTRB(insets.left, 8, insets.right, 0),
            child: Row(
              children: [
                Text(
                  '${_selectedIndex + 1} из ${items.length}',
                  style: UITextStyles.monoRegular12,
                ),
                const Spacer(),
                Icon(Icons.swipe_rounded, size: 16, color: UIColors.secondary1),
                const Margin.horizontal(8),
                Text('Листайте карточки', style: UITextStyles.regular13),
              ],
            ),
          ),
        const Margin.vertical(8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(left: insets.left, right: insets.right),
          child: Row(
            children: [
              for (final (index, item) in items.indexed) ...[
                if (index > 0) const Margin.horizontal(8),
                Container(
                  key: index == _selectedIndex ? _selectedTabKey : null,
                  child: Semantics(
                    button: true,
                    selected: index == _selectedIndex,
                    child: AppGestureDetector(
                      key: ValueKey('${widget.tabKeyPrefix}-${item.id}'),
                      onTap: () => _selectNote(index),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: SquircleBorders.squircleBorder(
                          color: index == _selectedIndex
                              ? UIColors.primary
                              : UIColors.cardBackground,
                          borderRadius: 16,
                          borderSide: index == _selectedIndex
                              ? BorderSide.none
                              : BorderSide(color: UIColors.borders),
                          shadows: [
                            BoxShadow(color: UIColors.shadows, blurRadius: 8),
                          ],
                        ),
                        child: Text(
                          '${index + 1}. ${item.title}',
                          style: UITextStyles.semibold14.copyWith(
                            color: index == _selectedIndex
                                ? UIColors.primaryButtonText
                                : UIColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = widget.insets;
    final items = widget.items;
    final pages = PageView.builder(
      controller: _pageController,
      itemCount: items.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(left: insets.left, right: insets.right),
        child: SingleChildScrollView(
          key: PageStorageKey('note-scroll-${items[index].id}'),
          primary: false,
          padding: EdgeInsets.only(
            top: insets.top,
            bottom: _navigationHeight + 24,
          ),
          child: widget.itemBuilder(context, index, index == _selectedIndex),
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        pages,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: MeasureHeight(
            onChange: (height) => setState(() => _navigationHeight = height),
            child: Column(
              children: [
                Divider(height: 1, color: UIColors.backgroundShapes1),
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      color: UIColors.pageBackground.withValues(alpha: .2),
                      padding: EdgeInsets.only(top: 8, bottom: insets.bottom),
                      child: _buildNavigation(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
