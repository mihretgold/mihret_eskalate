import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'dart:convert';
import 'details_page.dart';
import 'favorites_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final storage = GetStorage();
  int _selectedIndex = 0;
  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _filteredCountries = [];
  Set<String> _favoriteCountryNames = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterCountries);
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadFavorites();
    await _fetchCountries();
  }

  void _loadFavorites() {
    try {
      final favorites = storage.read<List>('favorites') ?? [];
      setState(() {
        _favoriteCountryNames = favorites.cast<String>().toSet();
      });
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  Future<void> _saveFavorites() async {
    try {
      await storage.write('favorites', _favoriteCountryNames.toList());
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  Future<void> _fetchCountries() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('Fetching countries from API...');
      final response = await http.get(
        Uri.parse('https://restcountries.com/v3.1/all?fields=name,flags,capital,area,region,subregion,population,timezones'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        debugPrint('API response received successfully');
        final List<dynamic> data = json.decode(response.body);
        debugPrint('Number of countries fetched: ${data.length}');

        setState(() {
          _countries = data.map((country) {
            try {
              final name = country['name']?['common'];
              if (name == null) {
                debugPrint('Country missing name: $country');
                return null;
              }

              final population = country['population'];
              if (population == null) {
                debugPrint('Country $name missing population');
                return null;
              }

              return {
                'name': name,
                'flag': country['flags']?['emoji'] ?? '🏳️',
                'capital': (country['capital'] as List?)?.firstOrNull ?? 'N/A',
                'area': country['area']?.toString() ?? 'N/A',
                'region': country['region'] ?? 'N/A',
                'subregion': country['subregion'] ?? 'N/A',
                'population': _formatPopulation(population),
                'timezones': (country['timezones'] as List?)?.cast<String>() ?? [],
                'isFavorite': _favoriteCountryNames.contains(name),
              };
            } catch (e) {
              debugPrint('Error processing country: $country');
              debugPrint('Error details: $e');
              return null;
            }
          })
          .where((country) => country != null) // Filter out null entries
          .cast<Map<String, dynamic>>() // Cast to the correct type
          .toList()
          ..sort((a, b) => a['name'].compareTo(b['name'])); // Sort countries alphabetically

          debugPrint('Successfully processed ${_countries.length} countries');
          _filteredCountries = List.from(_countries);
          _isLoading = false;
        });
      } else {
        debugPrint('API request failed with status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        setState(() {
          _error = 'Failed to load countries (Status: ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching countries: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _error = 'Error fetching countries: $e';
        _isLoading = false;
      });
    }
  }

  String _formatPopulation(dynamic population) {
    try {
      final numPopulation = population is int ? population : int.parse(population.toString());
      if (numPopulation >= 1000000000) {
        return '${(numPopulation / 1000000000).toStringAsFixed(2)}B';
      } else if (numPopulation >= 1000000) {
        return '${(numPopulation / 1000000).toStringAsFixed(1)}M';
      } else if (numPopulation >= 1000) {
        return '${(numPopulation / 1000).toStringAsFixed(1)}K';
      }
      return numPopulation.toString();
    } catch (e) {
      debugPrint('Error formatting population: $e');
      return 'N/A';
    }
  }

  void _filterCountries() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCountries = _countries.where((country) {
        final name = country['name'].toString().toLowerCase();
        final capital = country['capital'].toString().toLowerCase();
        return name.contains(query) || capital.contains(query);
      }).toList();
    });
  }

  void _toggleFavorite(int index) {
    setState(() {
      final country = _filteredCountries[index];
      final name = country['name'];
      final mainIndex = _countries.indexWhere((c) => c['name'] == name);
      
      // Update both lists to keep them in sync
      final newFavoriteState = !_filteredCountries[index]['isFavorite'];
      _filteredCountries[index]['isFavorite'] = newFavoriteState;
      if (mainIndex != -1) {
        _countries[mainIndex]['isFavorite'] = newFavoriteState;
      }

      // Update favorites set and save to SharedPreferences
      if (newFavoriteState) {
        _favoriteCountryNames.add(name);
      } else {
        _favoriteCountryNames.remove(name);
      }
      _saveFavorites();
    });
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    if (index == 1) {
      final favorites = _countries.where((country) => country['isFavorite']).toList();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FavoritesPage(
            favorites: favorites,
            onFavoriteRemoved: (countryName) {
              setState(() {
                // Update the main list
                final index = _countries.indexWhere((c) => c['name'] == countryName);
                if (index != -1) {
                  _countries[index]['isFavorite'] = false;
                }
                
                // Update the filtered list
                final filteredIndex = _filteredCountries.indexWhere((c) => c['name'] == countryName);
                if (filteredIndex != -1) {
                  _filteredCountries[filteredIndex]['isFavorite'] = false;
                }

                // Update favorites set
                _favoriteCountryNames.remove(countryName);
              });
            },
          ),
        ),
      ).then((_) {
        setState(() {
          _selectedIndex = 0;
        });
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Countries',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a country',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          // Countries List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchCountries,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredCountries.isEmpty
                        ? const Center(
                            child: Text(
                              'No countries found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchCountries,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredCountries.length,
                              itemBuilder: (context, index) {
                                final country = _filteredCountries[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DetailsPage(country: country),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
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
                                    child: Row(
                                      children: [
                                        // Flag
                                        Container(
                                          width: 48,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(4),
                                            color: Colors.grey[200],
                                          ),
                                          child: Center(
                                            child: Text(
                                              country['flag'],
                                              style: const TextStyle(fontSize: 20),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Country Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                country['name'],
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Capital: ${country['capital']}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Favorite Button
                                        IconButton(
                                          onPressed: () => _toggleFavorite(index),
                                          icon: Icon(
                                            country['isFavorite']
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: country['isFavorite']
                                                ? Colors.red
                                                : Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favourites',
          ),
        ],
      ),
    );
  }
}
