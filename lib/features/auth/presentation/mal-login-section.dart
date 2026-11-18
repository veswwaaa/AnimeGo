import 'package:flutter/material.dart';

import 'package:animego/core/auth/mal_auth_provider.dart';
import 'package:animego/core/auth/mal_auth_scope.dart';

/// Panel login MyAnimeList yang dipakai di Profile screen.
///
/// Menampilkan status: belum login, sedang login, error, dan sudah login
/// (username MAL + badge "MyAnimeList"), plus tombol logout.
class MalLoginSection extends StatelessWidget {
  const MalLoginSection({super.key});

  static const Color accent = Color(0xFFFF7A00);

  @override
  Widget build(BuildContext context) {
    final provider = MalAuthScope.of(context);

    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        switch (provider.status) {
          case MalAuthStatus.loading:
            return const MalCard(
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Menghubungkan MyAnimeList...'),
                ],
              ),
            );
          case MalAuthStatus.error:
            return MalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.errorMessage ?? 'Login gagal.',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 12),
                  MalLoginButton(onPressed: () => provider.login()),
                ],
              ),
            );
          case MalAuthStatus.loggedIn:
            return MalLoggedInCard(
              username: provider.user?.username ??
                  provider.cachedUsername ??
                  'MyAnimeList User',
              avatarUrl: provider.user?.avatarUrl,
              onLogout: () => provider.logout(),
            );
          case MalAuthStatus.unknown:
          case MalAuthStatus.loggedOut:
            return MalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sinkronkan list anime kamu dengan MyAnimeList.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  MalLoginButton(onPressed: () => provider.login()),
                ],
              ),
            );
        }
      },
    );
  }
}

/// Kartu container untuk bagian MAL.
class MalCard extends StatelessWidget {
  const MalCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF14141A),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

/// Tombol login MAL.
class MalLoginButton extends StatelessWidget {
  const MalLoginButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.link, size: 18),
        label: const Text('Login MyAnimeList'),
        style: ElevatedButton.styleFrom(
          backgroundColor: MalLoginSection.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

/// Kartu kondisi sudah login: username MAL + badge + tombol logout.
class MalLoggedInCard extends StatelessWidget {
  const MalLoggedInCard({
    super.key,
    required this.username,
    required this.onLogout,
    this.avatarUrl,
  });

  final String username;
  final String? avatarUrl;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return MalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage:
                    avatarUrl != null && avatarUrl!.isNotEmpty
                        ? NetworkImage(avatarUrl!)
                        : null,
                child: avatarUrl == null || avatarUrl!.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const MalBadge(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF2E2E38)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge "MyAnimeList".
class MalBadge extends StatelessWidget {
  const MalBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2E38),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 14, color: MalLoginSection.accent),
          SizedBox(width: 6),
          Text(
            'MyAnimeList',
            style: TextStyle(fontSize: 11, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
