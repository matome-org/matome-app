import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: MatomeApp()));
}

/// App root for the lab: boots Riverpod and renders the Home/Today screen,
/// which consumes the existing recordings controller.
class MatomeApp extends StatelessWidget {
  const MatomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Matome (Flutter Lab)',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
