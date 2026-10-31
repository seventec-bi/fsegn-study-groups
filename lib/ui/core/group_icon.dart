import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class GroupIcon extends StatelessWidget {
  final String emoji;
  final double size;
  final double radius;

  const GroupIcon({
    super.key,
    required this.emoji,
    this.size = 54,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppTheme.tealLight,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Text(emoji, style: TextStyle(fontSize: size * .48, height: 1.1)),
  );
}

class GroupIconPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  static const options = [
    '📚', '📖', '🧠', '📝', '📊', '🧮',
    '💻', '🌐', '🔬', '📐', '🎓', '✨',
  ];

  const GroupIconPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: options.map((emoji) {
      final active = emoji == selected;
      return Semantics(
        button: true,
        selected: active,
        label: 'Icône $emoji',
        child: InkWell(
          onTap: () => onSelected(emoji),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppTheme.tealLight : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? AppTheme.tealAccent : AppTheme.borderSubtle,
                width: active ? 2 : 1,
              ),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 23)),
          ),
        ),
      );
    }).toList(),
  );
}
