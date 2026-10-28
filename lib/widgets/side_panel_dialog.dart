import 'package:flauncher/actions.dart';
import 'package:flutter/material.dart';

import 'settings/settings_theme.dart';
import '../ui/liquid_glass.dart';

/// The sliding settings surface.
///
/// Dark glass material: a soft dark gradient with a faint accent glow in
/// the top corner and a single specular hairline on the inner edge. Deliberately
/// avoids [BackdropFilter] and elevation shadows, both of which force expensive
/// offscreen layers on TV GPUs.
class SidePanelDialog extends StatelessWidget {
  final Widget child;
  final double width;
  final bool isRightSide;

  const SidePanelDialog({
    required this.child,
    this.width = 250,
    this.isRightSide = false,
  });

  @override
  Widget build(BuildContext context) {
    // Arc TV: a floating Liquid Glass sheet, inset from the screen edges with
    // concentric rounded corners (Apple HIG), instead of an edge-attached panel.
    return Align(
      alignment: isRightSide ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          width: width,
          child: LiquidGlass(
            radius: SettingsStyle.panelRadius,
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Actions(
                  actions: {BackIntent: BackAction(context)},
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
