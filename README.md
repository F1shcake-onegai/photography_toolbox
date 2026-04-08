# OpenGrains

A companion app for analog photography, built with Flutter. Works on Android, iOS, Windows, macOS, and Linux.

## Features

### Flash Power
Calculate flash power or subject distance using guide number, ISO, and aperture. Supports standard flash power steps (1/1 to 1/64) and common f-stop values. Results update automatically as you adjust sliders or finish typing in input fields.

### Depth of Field Calculator
Compute hyperfocal distance and depth of field range from focal length, aperture, subject distance, and circle of confusion. Results show hyperfocal distance and near–far range at the bottom of the screen.

### Quick Note
Log your film rolls and individual shots. Each roll stores a title, brand, model, ISO, push/pull, comments, and a list of shots. Shots can include a sequence number, exposure compensation, GPS location (with map picker), photo (camera on mobile, file picker on desktop), and notes. Tap a shot image to open a full-screen viewer with pinch-to-zoom and save-to-gallery. Search, sort, and filter your rolls by brand, ISO, and title. Share rolls as `.ptroll` files with selectable shots, and import rolls received from others. New rolls are created via a bottom sheet with recent film stock shortcuts. Data is saved locally as JSON.

### Lightpad
Turn your screen into a light source with adjustable color, brightness, and transparency. Includes a fullscreen mode — long-press for 2 seconds to exit. Color picker supports hex input and HSV sliders.

### Reciprocity Failure Calculator
Compensate for reciprocity failure in long exposures. Select from 20 built-in film presets (Ilford, Kodak, Fuji — negative and slide) or create custom film profiles with your own Schwarzschild exponent and threshold. Enter the metered time via slider or exact input; see the corrected exposure time and extra stops needed.

### Light Meter
Camera-based light meter that reads live EV from your scene. Choose between center-weighted, matrix, and average metering modes, or tap the preview to set a point metering spot. Three exposure parameters (aperture, shutter speed, ISO) can be adjusted with arrow buttons; tap any parameter to make it the calculated one. Configurable exposure step size (1, 1/2, 1/3, 1/4 stops). Desktop shows a manual EV input fallback.

### Darkroom Timer
Create and manage darkroom development recipes with multi-step timers. Each recipe includes film stock, developer, dilution, process type (B&W/color negative/positive/paper), temperature compensation, notes, and agitation settings (including disable option). Selecting "Paper" process type auto-enables safelight mode. Built-in C-41 and E-6 recipes are included out of the box. Search, sort, and filter recipes by film stock, developer, process type, and dilution. Duplicate recipes to create variations. Share recipes as `.ptrecipe` files and import recipes from others. The running timer features an Apple Clock-style rolling step list, push notifications, haptic feedback, and a full darkroom safelight mode (pure black background for OLED, red-only UI elements).

### Chemical Mixer
Dilution calculator for darkroom chemicals. Supports additive (A+B) and ratio (A:B) notation with up to 4 parts. Enter the total volume and part ratios to see per-part volumes. Also accessible from the running timer page when a recipe has a dilution — opens pre-filled with the recipe's dilution pattern.

### Settings
- **Maximum aperture**: Configure the widest aperture stop available across calculators (e.g., f/0.95, f/1.0, f/1.4). Shared by Flash Power and Depth of Field calculators.
- **Exposure step**: Sets the increment size (1, 1/2, 1/3, 1/4 stops) for the light meter.
- **Language**: English, Japanese (日本語), Simplified Chinese (简体中文), or follow system locale.
- **Default import action**: Choose how to handle duplicates when importing recipes or rolls (ask, replace, skip, or import as copy).
- **Auto-capture location**: Automatically record GPS coordinates when creating a new shot (default: on). Requires location permission on mobile.

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
    flash_calculator_page.dart    # Flash power calculator
    dof_calculator_page.dart      # Depth of field calculator
    film_quick_note_page.dart     # Quick note roll list with search/sort/filter
    roll_detail_page.dart         # Single roll view with shots grid and sharing
    shot_page.dart                # Add/edit a shot
    image_viewer_page.dart        # Full-screen image viewer with pinch-to-zoom
    lightpad_page.dart            # Lightpad with color picker
    reciprocity_calculator_page.dart # Reciprocity failure calculator
    light_meter_page.dart         # Camera-based light meter
    darkroom_timer_page.dart      # Recipe list with search/sort/filter
    recipe_edit_page.dart         # Create/edit darkroom recipes
    timer_running_page.dart       # Active countdown timer with step progression
    chemical_mixer_page.dart      # Chemical dilution mixer
    map_picker_page.dart          # GPS location picker with OpenStreetMap
    settings_page.dart            # App settings
  services/
    aperture_settings.dart        # Shared aperture stop configuration
    app_localizations.dart        # JSON-based i18n with LocalizationsDelegate
    file_intent_service.dart      # Platform channel for OS file associations
    film_storage.dart             # CRUD + import/export for film rolls
    import_export_service.dart    # Centralized .ptrecipe/.ptroll file handling
    import_settings.dart          # Duplicate import action preference
    recipe_storage.dart           # CRUD + import/export for darkroom recipes
    reciprocity_storage.dart      # Film reciprocity presets + custom profile storage
    light_meter_constants.dart    # Photography value lists, EV math, exposure step settings
    locale_settings.dart          # Persists locale preference
    location_settings.dart        # Auto-capture location preference
    location_service.dart         # GPS position capture
  widgets/
    import_dialogs.dart           # Shared import duplicate handling bottom sheet
    input_decorations.dart        # Shared underline input decoration helpers
    list_search_bar.dart          # Shared search field + filter chip row
    responsive_layout.dart        # CalculatorLayout and MasonryList widgets
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
