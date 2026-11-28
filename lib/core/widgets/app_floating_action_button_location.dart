import 'package:flutter/material.dart';

/// Keeps nested-screen actions above the shell's overlaid bottom navigation.
class AppFloatingActionButtonLocation extends FloatingActionButtonLocation {
  AppFloatingActionButtonLocation(BuildContext context)
    : _navigationInset =
          (MediaQuery.paddingOf(context).bottom -
                  MediaQuery.viewPaddingOf(context).bottom)
              .clamp(0.0, double.infinity);

  final double _navigationInset;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final offset = FloatingActionButtonLocation.endFloat.getOffset(
      scaffoldGeometry,
    );
    return offset.translate(0, -_navigationInset);
  }
}
