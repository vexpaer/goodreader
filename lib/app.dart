import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'state/providers.dart';

class GoodReaderApp extends ConsumerWidget {
  const GoodReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return MaterialApp.router(
      title: 'GoodReader',
      debugShowCheckedModeBanner: false,
      themeMode: settings.app.themeMode,
      theme: AppTheme.build(
        seed: Color(settings.app.seedColor),
        brightness: Brightness.light,
      ),
      darkTheme: AppTheme.build(
        seed: Color(settings.app.seedColor),
        brightness: Brightness.dark,
      ),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
    );
  }
}
