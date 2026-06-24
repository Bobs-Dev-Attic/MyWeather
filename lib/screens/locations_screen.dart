import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/locations_controller.dart';
import 'search_screen.dart';

/// Manage saved locations: select, reorder and remove.
class LocationsScreen extends StatelessWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locations = context.watch<LocationsController>();
    final items = locations.locations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Locations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add location',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SearchScreen(),
            )),
          ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No saved locations yet.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const SearchScreen(),
                      )),
                      icon: const Icon(Icons.search),
                      label: const Text('Add a location'),
                    ),
                  ],
                ),
              ),
            )
          : ReorderableListView.builder(
              itemCount: items.length,
              onReorder: locations.reorder,
              itemBuilder: (context, i) {
                final loc = items[i];
                final isSelected = i == locations.selectedIndex;
                return ListTile(
                  key: ValueKey(loc.key),
                  leading: Icon(
                    loc.isCurrent ? Icons.my_location : Icons.place_outlined,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(loc.name),
                  subtitle: Text(loc.subtitle),
                  selected: isSelected,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        Icon(Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => locations.removeLocation(loc),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    locations.select(i);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
    );
  }
}
