import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'details_page.dart';

class FavoritesPage extends StatefulWidget {
  final List<Map<String, dynamic>> favorites;
  final Function(String) onFavoriteRemoved;

  const FavoritesPage({
    super.key,
    required this.favorites,
    required this.onFavoriteRemoved,
  });

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late List<Map<String, dynamic>> _favorites;
  final storage = GetStorage();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _favorites = List.from(widget.favorites);
    _loadFavorites();
  }

  void _loadFavorites() {
    try {
      final favoriteNames = storage.read<List>('favorites') ?? [];
      setState(() {
        _favorites = widget.favorites
            .where((country) => favoriteNames.contains(country['name']))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(int index) async {
    try {
      final country = _favorites[index];
      final countryName = country['name'] as String;

      // Call the callback to update HomePage
      widget.onFavoriteRemoved(countryName);

      // Update local state
      setState(() {
        _favorites.removeAt(index);
      });

      // Update storage
      final favorites = storage.read<List>('favorites') ?? [];
      favorites.remove(countryName);
      await storage.write('favorites', favorites);
    } catch (e) {
      debugPrint('Error removing favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing favorite: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Favorites',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? const Center(
                  child: Text(
                    'No favorites yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _favorites.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final country = _favorites[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailsPage(country: country),
                            ),
                          );
                        },
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.teal[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              country['flag'] ?? '🏳️',
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        title: Text(
                          country['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          'Capital: ${country['capital'] ?? 'Unknown'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.favorite, color: Colors.red),
                          onPressed: () => _removeFavorite(index),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
} 