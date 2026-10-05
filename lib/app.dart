import 'package:flutter/material.dart';
import 'package:nart_chat/utils/app_theme.dart';
import 'package:nart_chat/views/splash_view.dart';

/// Koyu temalı uygulama kabuğu.
class NartApp extends StatelessWidget {
  const NartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NART Chatbot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const SplashView(),
    );
  }
}
