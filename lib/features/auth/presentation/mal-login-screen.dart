import 'package:flutter/material.dart';

import 'package:animego/core/auth/mal_auth_scope.dart';

import 'mal-login-section.dart';

/// Halaman login MyAnimeList penuh (bisa dibuka sebagai route terpisah).
class MalLoginScreen extends StatelessWidget {
  const MalLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    MalAuthScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MyAnimeList'),
        backgroundColor: const Color(0xFF14141A),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Text(
                'Masuk dengan MyAnimeList',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'List anime dan progress tontonan akan tersinkron ke akun MAL kamu.',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 24),
              MalLoginSection(),
            ],
          ),
        ),
      ),
    );
  }
}
