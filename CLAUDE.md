# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
flutter pub get              # Install dependencies
flutter run                  # Run on connected device/emulator
flutter analyze              # Lint/static analysis (uses flutter_lints)
flutter build apk            # Build Android
flutter build ios            # Build iOS
flutter build windows        # Build Windows
flutter test                 # Run tests (no tests exist yet)
```

Requires Flutter SDK 3.10.3+. Web platform is disabled.

## Platform & Shell Quirks

This project is developed on **Cygwin (Windows)**. Key issues:

- **Use `python` not `python3`** — only `python` is available on PATH (`C:/Python312/python`).
- **Bash heredocs with Dart code fail** when the content contains mixed single quotes, `${}` interpolation, and backslashes. The tool layer wraps commands in a way that breaks heredoc quoting. Workarounds:
  - For simple files: `cat > file << 'EOF' ... EOF` works if content has no complex quoting.
  - For complex files: use `sed -i` for targeted replacements, or write a Python script via heredoc (Python code is simpler to quote) that reads/replaces/writes the Dart files.
  - For literal `\n` in Dart strings: Python `'\n'` still becomes a real newline when written through heredocs. Use `chr(92) + 'n'` in Python to produce the literal two-character sequence.
- **The `Write` and `Edit` tools sometimes fail** with `EEXIST: file already exists, mkdir` errors on existing directories. Fall back to `cat >` (via Bash) or `sed -i` or Python file writes when this happens.

## Architecture

Flutter app using Material 3, named routes, no state management package. `main.dart` defines all routes, holds the locale state, and registers the project license.

A `GestureDetector` in `MaterialApp.builder` dismisses the keyboard on tap outside text fields (all pages).

### i18n System

- **JSON-based** translations in `assets/i18n/{en,ja,zh}.json` — flat key-value maps.
- `AppLocalizations` loads JSON via `rootBundle`, accessed with `AppLocalizations.of(context).t('key')` (aliased as `l` in build methods).
- Parameterized strings use `{param}` placeholders: `l.t('key', {'param': value})`.
- `LocaleSettings` persists the chosen locale code (or `null` for "Follow System") in `SharedPreferences`.
- `PhotographyToolboxApp.setLocale(context, localeCode)` triggers a full app rebuild for locale changes.
- Unsupported locales fall back to English via `localeResolutionCallback`.
- When adding new user-facing strings: add the key to all three JSON files, then use `l.t('key')` in Dart.

### Services

- `ApertureSettings` — persists max aperture in SharedPreferences; `stopsFrom()` filters the aperture stop list. Shared by Flash Calculator and DOF Calculator.
- `FilmStorage` — CRUD for film rolls stored as `film_rolls.json` in app documents directory. Also manages `film_images/` directory for shot photos.
- `RecipeStorage` — CRUD for darkroom recipes stored as `recipes.json` in app documents directory. Also handles JSON import/export for recipe sharing.
- `LocaleSettings` — persists locale preference (`null` = follow system).

### Darkroom Timer

Three-page feature: recipe list → recipe editor → running timer.

**Recipe data model** (`recipes.json`):
- `filmStock`, `developer`, `dilution` — recipe identity fields
- `baseTemp` — `null` (N/A for color films), `20.0`, or `24.0`; drives Arrhenius temperature compensation on develop/custom steps
- `redSafelight` — boolean; auto-activates darkroom safelight mode in timer
- `steps[]` — ordered list, each with `type` (`develop`|`stop`|`fix`|`wash`|`rinse`|`custom`), `time` (seconds), optional `label`, optional `agitation` config, optional `speedWash` (wash only)
- `agitation` — `{ method: 'hand'|'rolling', initialDuration, period, duration, speed }`

**Timer page** (`timer_running_page.dart`):
- Apple Clock-style rolling step list with `AnimatedSwitcher` slide-up transitions
- Wall-clock based timing (tracks `DateTime.now()` for background accuracy)
- Agitation phase tracking: initial continuous → repeating (rest → agitate at end of period)
- Phase transitions trigger haptics + system sounds
- Push notifications for step completion and agitation starts (`flutter_local_notifications`, skipped on Windows)
- Safelight mode: full darkroom ColorScheme (deep black + red), auto-activated when recipe allows, tappable toggle
- `wakelock_plus` keeps screen on during timer

**Windows build note**: `flutter_local_notifications` Windows plugin requires ATL headers not available on this system. A no-op Dart stub (`windows_notifications_stub/`) overrides the Windows plugin via `dependency_overrides` in `pubspec.yaml`. Notifications are silently skipped on Windows; they work on Android/iOS.

**Bundled fonts**: Noto Sans (Latin), Noto Sans JP, Noto Sans SC in `assets/fonts/` with `fontFamilyFallback` in theme for CJK coverage.

### Key Patterns

- All feature pages use `AppDrawer` for navigation and have a back button that does `pushReplacementNamed(context, '/')`.
- Aperture sliders use index-based discrete sliders over the `ApertureSettings.stopsFrom()` list.
- Distance sliders use logarithmic scale (`log10` / `pow(10, v)`).
- Film rolls use millisecond timestamp as string ID.
- Recipes use millisecond timestamp as string ID.
- Lightpad fullscreen exit uses a 2-second long-press with animated ring progress (`_RingPainter`).
- Calculator result areas are pinned to the bottom of the screen with structured cards (small label + large bold value).
- Camera button in shot page is only shown on mobile (iOS/Android); desktop uses file picker only.
- `image_picker` camera requires `CAMERA` permission in AndroidManifest.xml and `NSCameraUsageDescription` in iOS Info.plist.
- iOS xcconfig files use `#include?` (optional include) for `Generated.xcconfig` to avoid build failures on fresh clones.
- Time inputs in recipe editor use paired minute/second numeric-only boxes (`_buildTimeInput` helper).
