import 'package:flutter/material.dart';

import 'package:animego/core/auth/mal_auth_provider.dart';
import 'package:animego/core/auth/mal_auth_scope.dart';
import 'package:animego/core/auth/mal_di.dart';
import 'package:animego/features/main-navigation/presentation/main-navigation.dart';

class AniStreamApp extends StatefulWidget {
  const AniStreamApp({super.key});

  @override
  State<AniStreamApp> createState() => _AniStreamAppState();
}

class _AniStreamAppState extends State<AniStreamApp> {
  late final MalAuthProvider _malAuth;

  @override
  void initState() {
    super.initState();
    _malAuth = MalDi.provider();
    // Restore session MAL dari secure storage saat app dibuka.
    _malAuth.restore();
  }

  @override
  void dispose() {
    _malAuth.dispose();
    super.dispose();
  }

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
      home: MalAuthScope(
        provider: _malAuth,
        child: const MainNavigationScreen(),
      ),
    );
  }
}
