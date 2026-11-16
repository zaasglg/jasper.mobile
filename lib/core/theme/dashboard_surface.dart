import 'package:flutter/material.dart';

abstract final class DashboardSurface {
  static const background = Colors.white;
  static const border = Color(0xFFE9EBF0);
  static const shadows = <BoxShadow>[
    BoxShadow(color: Color(0x080F172A), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x070F172A), blurRadius: 16, offset: Offset(0, 6)),
  ];
}
