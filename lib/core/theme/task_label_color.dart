import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Web labels can store CSS palette tokens as well as hexadecimal colors.
Color taskLabelColor(String value) {
  final token = switch (value.trim()) {
    'var(--label-red)' => '#E11D48',
    'var(--label-yellow)' => '#EAB308',
    'var(--label-green)' => '#16A34A',
    'var(--label-blue)' => '#2563EB',
    'var(--label-gray)' => '#94A3B8',
    'var(--label-purple)' || 'var(--accent)' => '#6D5FE0',
    _ => value.trim(),
  };
  var hex = token.replaceFirst('#', '');
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  if (hex.length == 6) hex = 'FF$hex';
  final parsed = hex.length == 8 ? int.tryParse(hex, radix: 16) : null;
  return parsed == null ? AppColors.accent : Color(parsed);
}
