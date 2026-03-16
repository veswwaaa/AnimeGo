import 'package:flutter/material.dart';
import '../../developer-screen/presentation/developer-screen.dart';

// ==========================================
// 4. PROFILE SCREEN
// ==========================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.orange, Colors.purpleAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Anime Fan',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'anime.fan@anistream.app',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            _buildProfileMenu(
              Icons.settings_outlined,
              'Settings',
              'Preferences and notifications',
            ),
            const SizedBox(height: 12),
            _buildProfileMenu(
              Icons.settings_outlined,
              'Developer Only',
              'Developer tools and options',
              context,
            ),
            const SizedBox(height: 12),
            _buildProfileMenu(
              Icons.info_outline,
              'About AniStream',
              'Version 1.0.0',
            ),
            const SizedBox(height: 12),
            _buildProfileMenu(
              Icons.open_in_new,
              'Help & Support',
              'FAQs and contact',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileMenu(IconData icon, String title, String subtitle, /* not must have context */ [BuildContext? context]) {
    return GestureDetector(
      onTap: () {
        if(context == null) return;
        if(title == 'Developer Only') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DeveloperScreen()),
          );
        }
      },

      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14141A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Icon(icon, color: Colors.grey),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
