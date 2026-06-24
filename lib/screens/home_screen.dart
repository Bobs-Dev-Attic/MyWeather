import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/weather_condition.dart';
import '../models/weather_data.dart';
import '../theme/weather_theme.dart';
import '../utils/formatting.dart';
import '../widgets/charts/hourly_chart.dart';
import '../widgets/current_weather_hero.dart';
import '../widgets/daily_forecast.dart';
import '../widgets/details_grid.dart';
import '../widgets/glass_card.dart';
import '../widgets/hourly_strip.dart';
import '../widgets/source_comparison.dart';
import '../widgets/weather_animations.dart';
import '../state/locations_controller.dart';
import '../state/settings_controller.dart';
import '../state/weather_controller.dart';
import 'historical_screen.dart';
import 'locations_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _loadedKey;
  String? _lastPrimary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLoad());
  }

  /// Loads weather when the selected location changes, and recomputes the
  /// primary bundle when the preferred primary source changes.
  void _syncLoad({bool force = false}) {
    if (!mounted) return;
    final locations = context.read<LocationsController>();
    final settings = context.read<SettingsController>().settings;
    final weather = context.read<WeatherController>();
    final selected = locations.selected;
    if (selected == null) return;

    if (force || _loadedKey != selected.key) {
      _loadedKey = selected.key;
      weather.load(selected, settings, force: force);
    } else if (_lastPrimary != settings.primarySourceId) {
      weather.recomputePrimary(settings);
    }
    _lastPrimary = settings.primarySourceId;
  }

  Future<void> _refresh() async {
    final locations = context.read<LocationsController>();
    final settings = context.read<SettingsController>().settings;
    final weather = context.read<WeatherController>();
    final selected = locations.selected;
    if (selected != null) {
      await weather.load(selected, settings, force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on relevant state changes and (re)trigger loads as needed.
    context.watch<LocationsController>();
    context.watch<SettingsController>();
    final weather = context.watch<WeatherController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLoad());

    final condition = weather.primary?.current.condition ??
        const WeatherCondition(
          category: WeatherCategory.unknown,
          description: '',
        );
    final settings = context.read<SettingsController>().settings;
    final fg = WeatherTheme.onGradient(condition);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AnimatedWeatherBackground(
        condition: condition,
        enabled: settings.animationsEnabled,
        reducedMotion: settings.reducedMotion,
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(foreground: fg),
              Expanded(child: _buildBody(context, fg)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Color fg) {
    final locations = context.watch<LocationsController>();
    final weather = context.watch<WeatherController>();

    if (!locations.hasSelection) {
      return _EmptyState(foreground: fg);
    }

    if (weather.status == LoadStatus.loading && weather.primary == null) {
      return Center(child: CircularProgressIndicator(color: fg));
    }

    if (weather.primary == null) {
      return _ErrorState(
        message: weather.error ?? 'Could not load weather.',
        foreground: fg,
        onRetry: () => _syncLoad(force: true),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: _content(context, fg),
    );
  }

  Widget _content(BuildContext context, Color fg) {
    final settings = context.watch<SettingsController>().settings;
    final weather = context.watch<WeatherController>();
    final bundle = weather.primary!;
    final fmt = Formatting(settings.use24HourClock);
    final today = bundle.daily.isNotEmpty ? bundle.daily.first : null;

    DailyPoint? matchToday(List<DailyPoint> days) {
      final now = DateTime.now();
      for (final d in days) {
        if (d.date.year == now.year &&
            d.date.month == now.month &&
            d.date.day == now.day) {
          return d;
        }
      }
      return days.isNotEmpty ? days.first : null;
    }

    final todayPoint = matchToday(bundle.daily) ?? today;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        CurrentWeatherHero(
          location: bundle.location,
          current: bundle.current,
          today: todayPoint,
          settings: settings,
          foreground: fg,
        ),
        const SizedBox(height: 8),
        if (weather.lastUpdated != null)
          Center(
            child: Text(
              'Updated ${Formatting.ago(weather.lastUpdated!)} · ${bundle.sourceName}',
              style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),

        // Multi-source comparison.
        if (weather.resultsWithData.length > 1) ...[
          GlassCard(
            child: SourceComparison(
              results: weather.results,
              settings: settings,
              foreground: fg,
              primarySourceId: bundle.sourceId,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Hourly strip + chart.
        if (bundle.hourly.isNotEmpty) ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Hourly forecast', fg),
                const SizedBox(height: 8),
                HourlyStrip(
                  points: bundle.hourly,
                  settings: settings,
                  foreground: fg,
                ),
                const SizedBox(height: 12),
                HourlyChart(
                  points: bundle.hourly,
                  tempUnit: settings.temperatureUnit,
                  formatting: fmt,
                  color: fg,
                ),
                if (bundle.hourly
                    .any((p) => (p.precipitationProbability ?? 0) > 0)) ...[
                  const SizedBox(height: 8),
                  _SectionTitle('Chance of precipitation', fg, small: true),
                  const SizedBox(height: 8),
                  PrecipChart(
                    points: bundle.hourly,
                    formatting: fmt,
                    color: fg,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Daily forecast.
        if (bundle.daily.isNotEmpty) ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('${bundle.daily.length}-day forecast', fg),
                const SizedBox(height: 8),
                DailyForecastList(
                  days: bundle.daily,
                  settings: settings,
                  foreground: fg,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Details grid.
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle('Details', fg),
              const SizedBox(height: 12),
              DetailsGrid(
                current: bundle.current,
                today: todayPoint,
                settings: settings,
                foreground: fg,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Historical entry point.
        GlassCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.history, color: fg),
            title: Text('Historical weather',
                style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
            subtitle: Text('Charts of past temperature and rainfall',
                style: TextStyle(color: fg.withValues(alpha: 0.7))),
            trailing: Icon(Icons.chevron_right, color: fg),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => HistoricalScreen(location: bundle.location),
              ));
            },
          ),
        ),
        const SizedBox(height: 16),

        if (bundle.attribution != null)
          Center(
            child: Text(
              bundle.attribution!,
              textAlign: TextAlign.center,
              style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.foreground});
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final locations = context.watch<LocationsController>();
    final selected = locations.selected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.list, color: foreground),
            tooltip: 'Locations',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const LocationsScreen(),
            )),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LocationsScreen(),
              )),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected?.isCurrent ?? false)
                    Icon(Icons.my_location, size: 16, color: foreground),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      selected?.name ?? 'MyWeather',
                      style: TextStyle(
                          color: foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.expand_more, color: foreground),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.search, color: foreground),
            tooltip: 'Search',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SearchScreen(),
            )),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: foreground),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SettingsScreen(),
            )),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.color, {this.small = false});
  final String text;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: small ? 13 : 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.foreground});
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final locations = context.watch<LocationsController>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_outlined, size: 56, color: foreground),
              const SizedBox(height: 12),
              Text('Welcome to MyWeather',
                  style: TextStyle(
                      color: foreground,
                      fontSize: 20,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Add a location to see the forecast from multiple sources.',
                textAlign: TextAlign.center,
                style: TextStyle(color: foreground.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: locations.isLocating
                    ? null
                    : () => locations.useCurrentLocation(),
                icon: locations.isLocating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: const Text('Use my location'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SearchScreen(),
                )),
                style: OutlinedButton.styleFrom(
                  foregroundColor: foreground,
                  side: BorderSide(color: foreground.withValues(alpha: 0.5)),
                ),
                icon: const Icon(Icons.search),
                label: const Text('Search locations'),
              ),
              if (locations.locationError != null) ...[
                const SizedBox(height: 12),
                Text(
                  locations.locationError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.foreground,
    required this.onRetry,
  });

  final String message;
  final Color foreground;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: foreground),
              const SizedBox(height: 12),
              Text('Could not load weather',
                  style: TextStyle(
                      color: foreground,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: foreground.withValues(alpha: 0.8))),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
