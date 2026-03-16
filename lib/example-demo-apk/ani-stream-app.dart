import 'package:flutter/material.dart';
import './features/main-navigation/presentation/main-navigation.dart';


class AniStreamApp extends StatelessWidget {
  const AniStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AniStream',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D12),
        primaryColor: const Color(0xFFFF7A00),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF7A00),
          secondary: Color(0xFFFF7A00),
          surface: Color(0xFF1C1C24),
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainNavigationScreen(),
    );
  }
}