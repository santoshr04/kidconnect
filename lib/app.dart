import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_router.dart';

/// SnapPix-AI — AI Photo Upload with Face Detection and Auto-Tagging
class SnapPixAiApp extends ConsumerWidget {
  const SnapPixAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SnapPix-AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}