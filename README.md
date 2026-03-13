# Photography Toolbox

A companion app for analog photography, built with Flutter. Works on Android, iOS, Windows, macOS, and Linux.

## Features

### Flash Calculator
Calculate flash power or subject distance using guide number, ISO, and aperture. Supports standard flash power steps (1/1 to 1/64) and common f-stop values. Results display at the bottom with structured cards showing required power and suggested setting.

### Depth of Field Calculator
Compute hyperfocal distance and depth of field range from focal length, aperture, subject distance, and circle of confusion. Results show hyperfocal distance and near–far range at the bottom of the screen.

### Film Quick Note
Log your film rolls and individual shots. Each roll stores brand, model, ISO, comments, and a list of shots. Shots can include a sequence number, photo (camera on mobile, file picker on desktop), and notes. Data is saved locally as JSON.

### Lightpad
Turn your screen into a light source with adjustable color, brightness, and transparency. Includes a fullscreen mode — long-press for 2 seconds to exit. Color picker supports hex input and HSV sliders.

### Darkroom Clock
_Coming soon._

### Settings
- **Maximum aperture**: Configure the widest aperture stop available across calculators (e.g., f/0.95, f/1.0, f/1.4). Shared by Flash Calculator and Depth of Field Calculator.
- **Language**: English, Japanese (日本語), Simplified Chinese (简体中文), or follow system locale.

## Localization

The app supports English, Japanese, and Simplified Chinese. Translations are stored as JSON in `assets/i18n/`. The language can be changed in Settings or left to follow the system locale; unsupported locales fall back to English.

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.10.3 or later)

### Run
```bash
flutter pub get
flutter run
```

### Build
```bash
# Android
flutter build apk

# iOS
flutter build ios

# Windows
flutter build windows

# macOS
flutter build macos

# Linux
flutter build linux
```

## Project Structure

```
lib/
  main.dart                       # App entry point, routes, locale state, license registration
  pages/
    home_page.dart                # Home screen with feature grid
    flash_calculator_page.dart    # Flash calculator
    dof_calculator_page.dart      # Depth of field calculator
    film_quick_note_page.dart     # Film roll list
    roll_detail_page.dart         # Single roll view with shots
    shot_page.dart                # Add/edit a shot
    lightpad_page.dart            # Lightpad with color picker
    darkroom_clock_page.dart      # Darkroom clock (placeholder)
    settings_page.dart            # App settings
  services/
    aperture_settings.dart        # Shared aperture stop configuration
    app_localizations.dart        # JSON-based i18n with LocalizationsDelegate
    film_storage.dart             # JSON-based local storage for film rolls
    locale_settings.dart          # Persists locale preference
  widgets/
    app_drawer.dart               # Navigation drawer for feature pages
assets/
  i18n/
    en.json                       # English translations
    ja.json                       # Japanese translations
    zh.json                       # Simplified Chinese translations
```

## License

This project is dedicated to the public domain under the CC0 1.0 Universal license. See [LICENSE](LICENSE) for details.

## Author

[@f1shcake_onegai](https://github.com/F1shcake-onegai)
