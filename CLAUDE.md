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
- `ReciprocityStorage` — CRUD for custom reciprocity film profiles stored as `reciprocity_profiles.json` in app documents directory. Also contains hardcoded preset data for 20 common films (Ilford, Kodak, Fuji — both negative and slide).
- `LightMeterConstants` — photography value lists (aperture, shutter, ISO) in full/half/third/quarter stops, EV math functions, and exposure step settings persistence via `ExposureStepSettings`.
- `ImportExportService` — centralized import/export for recipes (`.ptrecipe` JSON) and rolls (`.ptroll` ZIP archive with `roll.json` + `images/`). Handles file parsing, type detection, image dimension validation, and preview summaries. Both `RecipeStorage` and `FilmStorage` delegate export/import to this service.
- `FileIntentService` — platform channel bridge (`photography_toolbox/file_intent`) for handling OS "Open with…" file associations. Cold start uses `MethodChannel.getInitialFile`; warm start uses `EventChannel` stream. Native code (Kotlin/Swift) copies content:// or security-scoped URLs to temp cache files. Pages check `FileIntentService.pendingFilePath` after loading to auto-trigger import.
- `ImportSettings` — persists default duplicate import action (`ask`/`replace`/`skip`/`duplicate`) in SharedPreferences.
- `LocaleSettings` — persists locale preference (`null` = follow system).

### Darkroom Timer

Three-page feature: recipe list → recipe editor → running timer.

**Recipe data model** (`recipes.json`):
- `id` — UUID v4 string
- `createdAt` — milliseconds since epoch
- `filmStock`, `developer`, `dilution` — recipe identity fields
- `processType` — `'bw_neg'`|`'bw_pos'`|`'color_neg'`|`'color_pos'`|`'paper'` (user-selected, defaults to `bw_neg`)
- `notes` — free-text notes field
- `baseTemp` — `null` (N/A for color films), `20.0`, or `24.0`; drives Arrhenius temperature compensation on develop/custom steps
- `redSafelight` — boolean; auto-activates darkroom safelight mode in timer
- `steps[]` — ordered list, each with `type` (`develop`|`stop`|`fix`|`wash`|`rinse`|`custom`), `time` (seconds), optional `label`, optional `agitation` config, optional `speedWash` (wash only)
- `agitation` — `{ method: 'hand'|'rolling', initialDuration, period, duration, speed }`

**Built-in recipes**: Color Negative (C-41) and Color Reversal (E-6) are seeded on first launch via `RecipeStorage._builtInRecipes()` when `recipes.json` doesn't exist. Users can duplicate and modify them.

**Recipe list** (`darkroom_timer_page.dart`):
- Search/sort/filter via `ListSearchBar` widget
- Auto-tags derived at runtime (internal — used for filtering only, not displayed on cards): process type, developer, film stock, dilution
- Sort options: Film Stock (A-Z), Date Created (newest), Developer (A-Z)
- Recipe cards show edit, duplicate, and share action buttons; duplicate requires confirmation dialog
- Import button accepts `.ptrecipe`/`.json` files with preview confirmation and duplicate handling

**Recipe editor** (`recipe_edit_page.dart`):
- Auto-saves on back navigation (no confirm button) via `PopScope`
- Red delete icon in AppBar (only when editing existing recipe)
- Step reordering with up/down arrow buttons
- Process types: B&W Negative, B&W Reversal, Color Negative, Color Reversal, Paper

**Timer page** (`timer_running_page.dart`):
- Apple Clock-style rolling step list with `AnimatedSwitcher` slide-up transitions
- Wall-clock based timing (tracks `DateTime.now()` for background accuracy)
- Agitation phase tracking: initial continuous → repeating (rest → agitate at end of period)
- Phase transitions trigger haptics + system sounds
- Push notifications for step completion and agitation starts (`flutter_local_notifications`, skipped on Windows)
- Safelight mode: full darkroom ColorScheme (deep black + red), auto-activated when recipe allows, tappable toggle
- `wakelock_plus` keeps screen on during timer
- Chemical Mixer shortcut in AppBar (beaker icon) when recipe has a dilution — opens mixer pre-filled

**Windows build note**: `flutter_local_notifications` Windows plugin requires ATL headers not available on this system. A no-op Dart stub (`windows_notifications_stub/`) overrides the Windows plugin via `dependency_overrides` in `pubspec.yaml`. Notifications are silently skipped on Windows; they work on Android/iOS.

**Bundled fonts**: Noto Sans (Latin), Noto Sans JP, Noto Sans SC in `assets/fonts/` with `fontFamilyFallback` in theme for CJK coverage.

### Film Quick Note

Roll list → roll detail → shot editor / image viewer. Displayed as "Quick Note" in the UI.

**Roll data model** (`film_rolls.json`):
- `id` — UUID v4 string (legacy timestamp IDs auto-migrated)
- `createdAt` — milliseconds since epoch
- `brand`, `model`, `sensitivity` — roll identity fields
- `ec` — exposure compensation (double, 0.0 default)
- `comments` — free-text notes (auto-saved with 500ms debounce)
- `shots[]` — ordered by sequence number then createdAt timestamp; each shot has `uuid`, `sequence`, `imagePath`, `comment`, `createdAt`

**Roll list** (`film_quick_note_page.dart`):
- Search/sort/filter via `ListSearchBar` widget
- Auto-tags derived at runtime (internal — used for filtering only, not displayed on cards): brand, model, ISO, exposure compensation (Yes/No)
- Sort options: Name (A-Z), Date Created (newest), ISO (ascending)
- Import button accepts `.ptroll`/`.json`/`.zip` files with small-image warnings, preview confirmation, and duplicate handling

**Roll detail** (`roll_detail_page.dart`):
- Exposure compensation slider (-3 to +3, snaps to exposure step setting) next to ISO input
- Double-tap EC label to reset to 0

- 3-column shot grid; tap image → image viewer, tap empty → shot editor, long press → editor
- Share button with shot selection dialog (select all/none, shot count display)
- Export as `.ptroll` ZIP archive via `share_plus`

**Image viewer** (`image_viewer_page.dart`):
- Full-screen with `InteractiveViewer` (1x–5x zoom, pan)
- "Save to Gallery" button on mobile via `gal` package; hidden on desktop
- Black background, transparent AppBar

### Chemical Mixer

Single-page dilution calculator (`chemical_mixer_page.dart`). Displayed as "Chemical Mixer" on home grid.

- **Notation toggle**: `A + B` (additive — total = sum of parts) vs `A : B` (ratio — last number is total)
- **Structured numeric inputs**: no symbol typing needed, each part gets its own number field
- **Multi-part support**: up to 4 parts (Stock/Water default, expandable to Part A/B/C + Water)
- **Live results**: bottom card updates as user types, showing per-part volumes + total
- **Recipe integration**: timer running page shows beaker icon in AppBar when recipe has dilution; opens mixer pre-filled by regex-extracting numeric pattern from dilution string (handles mixed text like "B (1+31)")
- Result card style matches Flash Power / DOF calculators (pinned bottom, `surfaceContainerHighest`)

### Light Meter

Camera-based light meter (`light_meter_page.dart`) with `WidgetsBindingObserver` for lifecycle management.

- Live camera preview via `camera` package with `startImageStream` for frame-by-frame luminance analysis
- EV formula: `EV₁₀₀ = log2(N² / t)`, adjusted for ISO
- Three base metering modes: center-weighted (Gaussian), matrix (center-biased zones), average
- Point metering: tap anywhere on the preview to override with spot metering (independent of mode selector); "× Point" chip clears the active point
- Three exposure parameters (aperture, shutter, ISO) with `<` `>` arrows; tap a parameter to make it the calculated one (arrows hidden, value auto-computed)
- Configurable exposure step size (1, 1/2, 1/3, 1/4 stops) via Settings → persisted in `ExposureStepSettings`
- Platform guard: desktop shows manual EV text input instead of camera

### Reciprocity Failure Calculator

Single-page calculator (`reciprocity_calculator_page.dart`) following the flash/DOF calculator pattern.

- Schwarzschild power law: `t_corrected = t_metered ^ p` with per-film exponent and threshold
- 20 built-in film presets (Ilford, Kodak, Fuji — B&W, color negative, and slide) hardcoded in `ReciprocityStorage.presets`
- Custom film profiles: user can add/edit/delete via bottom sheet, persisted as JSON (`reciprocity_profiles.json`)
- Film dropdown groups presets by brand with section headers; custom profiles appended; "Manage Custom Films..." action at bottom
- Metered time: discrete slider (0.5s–960s) + exact text field override
- Results: corrected time (formatted as hours/min/sec) + extra stops

### Search, Sort & Filter

Both recipe and roll list pages share the same pattern via `ListSearchBar` widget:
- AppBar has search toggle icon and sort `PopupMenuButton`
- `ListSearchBar` renders a search `TextField` + per-field dropdown `FilterField` panels
- `FilterField` model supports `displayLabels` for translated filter values (e.g., EC Yes/No)
- Tags are auto-derived at runtime from item fields (not stored); internal only (not displayed on cards)
- Cascading filter visibility: `_itemsExcludingCategory()` filters by all active filters except the target category before collecting unique values — impossible combinations are hidden
- Filter logic: OR within category, AND across categories
- `_applyFilters()` chains: text search → chip filters → sort → `setState`
- "No results" empty state when filters yield nothing but items exist

### Import / Export

- **Recipes**: exported as `.ptrecipe` (pretty-printed JSON with `_type: "recipe"`, UUID preserved for duplicate detection)
- **Rolls**: exported as `.ptroll` (ZIP archive containing `roll.json` + `images/` directory with shot photos)
- Import flow: file picker / file intent → parse & validate → small-image warning (rolls) → preview confirmation dialog → duplicate handling (`ask`/`replace`/`skip`/`duplicate`) → import → snackbar feedback
- `ImportExportService.parseImportFile()` detects type from extension or content; validates required fields; extracts images to temp directory; checks image dimensions (min 100x100)
- File associations: `.ptrecipe` and `.ptroll` registered with Android (intent filters) and iOS (UTExportedTypeDeclarations + CFBundleDocumentTypes); native code copies to cache; `FileIntentService` passes path to Dart; target page auto-triggers import on load

### Key Patterns

- All feature pages use `AppDrawer` for navigation (with `drawerEnableOpenDragGesture: false` to prevent conflict with back swipe) and have a back button that does `Navigator.pop(context)`. The drawer uses `pushReplacementNamed` to swap between feature pages (keeping Home at the stack bottom).
- Home page has a gear icon (top-right) linking to Settings. Settings page has a tappable version row that opens the About dialog.
- Aperture sliders use index-based discrete sliders over the `ApertureSettings.stopsFrom()` list.
- All slider labels use `SizedBox(width: 56)` for consistent track lengths (except Lightpad and EC sliders).
- Distance sliders use logarithmic scale (`log10` / `pow(10, v)`).
- Film rolls and recipes use UUID v4 as string ID (legacy timestamp IDs auto-migrated on load).
- Lightpad fullscreen exit uses a 2-second long-press with animated ring progress (`_RingPainter`).
- Calculator result areas are pinned to the bottom of the screen with structured cards (small label + large bold value) in `surfaceContainerHighest` container with rounded top corners.
- Camera button in shot page is only shown on mobile (iOS/Android); desktop uses file picker only.
- `image_picker` camera requires `CAMERA` permission in AndroidManifest.xml and `NSCameraUsageDescription` in iOS Info.plist.
- iOS xcconfig files use `#include?` (optional include) for `Generated.xcconfig` to avoid build failures on fresh clones.
- Time inputs in recipe editor use paired minute/second numeric-only boxes (`_buildTimeInput` helper).
