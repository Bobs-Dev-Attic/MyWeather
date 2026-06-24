import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/geo_location.dart';
import '../services/geocoding_service.dart';
import '../state/locations_controller.dart';

/// Lets the user search for a place by name or address and add it.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<GeoLocation> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final geocoding = context.read<GeocodingService>();
      final results = await geocoding.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        if (results.isEmpty) _error = 'No places found for "$query".';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Search failed. Check your connection and try again.';
      });
    }
  }

  Future<void> _add(GeoLocation location) async {
    await context.read<LocationsController>().addLocation(location);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locations = context.watch<LocationsController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search locations'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'City, town or address…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: locations.isLocating
                    ? null
                    : () async {
                        await locations.useCurrentLocation();
                        if (mounted &&
                            locations.locationError == null &&
                            locations.hasSelection) {
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      },
                icon: const Icon(Icons.my_location),
                label: const Text('Use my current location'),
              ),
            ),
          ),
          if (locations.locationError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(locations.locationError!,
                  style: const TextStyle(color: Colors.red)),
            ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Type a place name to search.\nWeather data comes from multiple free sources.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = _results[i];
        return ListTile(
          leading: const Icon(Icons.place_outlined),
          title: Text(r.name),
          subtitle: Text(r.subtitle),
          trailing: const Icon(Icons.add),
          onTap: () => _add(r),
        );
      },
    );
  }
}
