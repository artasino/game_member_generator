import 'package:flutter/material.dart';

import '../../domain/entities/gender.dart';

/// アプリ全体で統一されたセクションヘッダー
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const AppSectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
      ],
    );
  }
}

/// アプリ全体で統一されたバッジ（ラベル）
class AppBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool isFilled;
  final double scale;

  const AppBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.isFilled = false,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: isFilled ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8 * scale),
        border: isFilled
            ? null
            : Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: 12 * scale, color: isFilled ? Colors.white : color),
            SizedBox(width: 4 * scale),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10 * scale,
              fontWeight: FontWeight.w900,
              color: isFilled ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 性別に応じた色やスタイルを提供するユーティリティ
class GenderTheme {
  static Color getColor(Gender gender) =>
      gender == Gender.male ? Colors.blue.shade700 : Colors.pink.shade600;

  static IconData getIcon(Gender gender) =>
      gender == Gender.male ? Icons.male : Icons.female;
}

/// ダイアログなどで使用する統一されたアクションボタン
/// main.dart の theme で設定されたスタイルを継承します
class AppActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final Color? color;

  const AppActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isPrimary = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return FilledButton(
        onPressed: onPressed,
        style: color != null
            ? FilledButton.styleFrom(backgroundColor: color)
            : null,
        child: Text(label),
      );
    }
    return TextButton(
      onPressed: onPressed,
      style:
          color != null ? TextButton.styleFrom(foregroundColor: color) : null,
      child: Text(label),
    );
  }
}
