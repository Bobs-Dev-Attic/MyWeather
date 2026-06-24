import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'state/settings_controller.dart';
import 'theme/weather_theme.dart';

class MyWeatherApp extends StatelessWidget {
  const MyWeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode =
        context.select<SettingsController, ThemeMode>((c) => c.settings.themeMode);

    return MaterialApp(
      title: 'MyWeather',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: WeatherTheme.light(),
      darkTheme: WeatherTheme.dark(),
      home: const HomeScreen(),
    );
  }
}
