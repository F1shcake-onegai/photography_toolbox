import 'package:shared_preferences/shared_preferences.dart';

class ApertureSettings {
  static const String _key = 'max_aperture';
  static const double defaultMaxAperture = 1.4;

  static const List<double> allStops = [
    0.95, 1.0, 1.2, 1.4, 1.8, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0, 32.0,
  ];

  static const List<double> maxApertureOptions = [
    0.95, 1.0, 1.2, 1.4, 1.8,
  ];

  static Future<double> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_key) ?? defaultMaxAperture;
  }

  static Future<void> save(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, value);
  }

  static List<double> stopsFrom(double maxAperture) {
    return allStops.where((s) => s >= maxAperture).toList();
  }
}
