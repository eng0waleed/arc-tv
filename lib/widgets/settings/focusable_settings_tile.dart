import 'package:flutter/material.dart';

import 'settings_theme.dart';

/// A single settings row with subtle focus feedback.
///
/// The visual chrome (glass fill, specular border, lift) lives in
/// [SettingsFocusCard]; this widget only lays out the leading icon, text and
/// trailing control. Behaviour is unchanged: OK/Enter still invokes
/// [onPressed], and the row is still a single focus target.
class FocusableSettingsTile extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onPressed;
  final bool autofocus;

  /// Shows a disclosure chevron when no [trailing] widget is provided.
  final bool showChevron;

  /// Draws a tinted squircle behind [leading] when it is an icon. Disable for
  /// radio indicators, which should read as plain marks.
  final bool frameLeading;

  const FocusableSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onPressed,
    this.autofocus = false,
    this.showChevron = false,
    this.frameLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    final baseTextStyle = Theme.of(context).textTheme.bodyMedium ?? const TextStyle(fontSize: 14);

    return SettingsFocusCard(
      autofocus: autofocus,
      onPressed: onPressed,
      builder: (context, highlighted) {
        // Arc TV (tvOS HIG): the focused row is white, so its text and icons turn dark.
        final content = DefaultTextStyle.merge(
          style: baseTextStyle.copyWith(color: Colors.white),
          child: IconTheme.merge(
            data: IconThemeData(size: SettingsStyle.iconSize, color: Colors.white.withValues(alpha: 0.9)),
            child: Row(
              children: [
                if (leading != null) ...[
                  SizedBox(width: SettingsStyle.iconChipSize - 6, child: Center(child: leading!)),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: subtitle != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [title, const SizedBox(height: 2), subtitle!],
                        )
                      : title,
                ),
              ],
            ),
          ),
        );
        return Row(
          children: [
            Expanded(child: highlighted ? _DarkOnLight(child: content) : content),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ] else if (showChevron) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: highlighted ? const Color(0x99000000) : Colors.white.withValues(alpha: 0.35),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Renders light content as dark (luminance inverted, colours removed), for
/// text and icons sitting on a focused white row.
class _DarkOnLight extends StatelessWidget {
  final Widget child;

  const _DarkOnLight({required this.child});

  static const ColorFilter _filter = ColorFilter.matrix(<double>[
    -0.299, -0.587, -0.114, 0, 255, //
    -0.299, -0.587, -0.114, 0, 255, //
    -0.299, -0.587, -0.114, 0, 255, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) => ColorFiltered(colorFilter: _filter, child: child);
}
