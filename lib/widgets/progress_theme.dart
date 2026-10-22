import 'package:flutter/material.dart';

/// Opt into Flutter's updated Material 3 progress geometry for the whole app.
const materialProgressTheme = ProgressIndicatorThemeData(
  // Required by Flutter 3.41 until the new geometry becomes the default.
  // ignore: deprecated_member_use
  year2023: false,
  // Inline spinners already have constrained 16–24 dp button/icon slots.
  circularTrackPadding: EdgeInsets.zero,
);
