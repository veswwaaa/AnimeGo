import 'package:flutter/material.dart';

import 'package:animego/core/dto/anime_dto.dart';
import 'package:animego/core/models/anime_mapper.dart';
import 'package:animego/core/providers/provider_container.dart';
import 'package:animego/core/utils/utils.dart';
import 'package:animego/features/anime-detail-screen/presentation/anime-detail-screen.dart';
import 'package:animego/features/search-screen/presentation/widgets/anime-search-results.dart';

// ==========================================
// 2. SEARCH SCREEN
// ==========================================
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = [
    'All',
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Fantasy',
  ];

  int _selectedCategoryIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;
  List<AnimeDto> _searchResults = const <AnimeDto>[];

  /// Provider aktif; `auto` mencoba semua provider berurutan.
  String _selectedProviderId = 'auto';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final order = _selectedProviderId == 'auto'
          ? null
          : <String>[_selectedProviderId];
      final envelope = await ProviderContainer.instance.repository.search(
        query,
        providerOrder: order,
      );
      if (!mounted) {
        return;
      }

      if (!envelope.isSuccess) {
        setState(() {
          _errorMessage =
              envelope.error?.message ??
              'Gagal mencari anime. Cek koneksi lalu coba lagi.';
          _searchResults = const <AnimeDto>[];
        });
        return;
      }

      setState(() {
        _searchResults = envelope.data ?? const <AnimeDto>[];
      });
    } catch (error, stackTrace) {
      logError(
        'SearchScreen._onSearch gagal untuk query "$query"',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Gagal mencari anime. Cek koneksi lalu coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openAnimeDetail(AnimeDto anime) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimeDetailScreen(anime: animeDtoToModel(anime)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search anime...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1C1C24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _onSearch,
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedCategoryIndex;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(
                      _categories[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedCategoryIndex = index;
                      });
                    },
                    selectedColor: const Color(0xFFFF7A00),
                    backgroundColor: const Color(0xFF1C1C24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildSourceSwitcher(),
          const SizedBox(height: 16),
          Expanded(
            child: AnimeSearchResults(
              results: _searchResults,
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              onTapAnime: _openAnimeDetail,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSwitcher() {
    final entries = <String, String>{
      'auto': 'Auto',
      for (final provider in ProviderContainer.instance.registry.all)
        provider.id: provider.displayName,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: entries.entries.map((entry) {
            final isSelected = entry.key == _selectedProviderId;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedProviderId = entry.key;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFF7A00)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
