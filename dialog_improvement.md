# Dialog Improvement Plan

## Current State
22 dialogs across 9 files, all using standard Material AlertDialog.

## Issues

### 1. Inconsistent button hierarchy
Some dialogs use `FilledButton` for primary action (import confirm, create roll), others use plain `TextButton` for both actions (discard, delete recipe). Rule:
- Destructive confirms → `FilledButton` with error color
- Non-destructive confirms → `FilledButton` with primary color
- Cancel → always `TextButton`

### 2. Delete confirmations too plain
"Delete roll with all photos" looks identical to "Discard empty form". Destructive dialogs need a warning icon and stronger visual weight to prevent accidental taps.

### 3. Form dialogs (New Roll, Custom Profile) feel cramped
TextField labels + OutlinedBorder stacked in AlertDialog leaves little breathing room. Better as full-width bottom sheets with more padding.

### 4. No icons anywhere
Every dialog is title + text + buttons. Add leading icons:
- Warning triangle for destructive actions
- Info circle for previews
- Check circle for success

### 5. Import preview is bare
Roll/recipe preview just lists raw text lines. A small structured card showing the import summary would feel more polished.

## Priority
Highest impact, lowest effort: standardize button hierarchy across all dialogs and add icons to destructive confirmation dialogs.

## Dialog Inventory

| File | Count | Dialogs |
|------|-------|---------|
| recipe_edit_page.dart | 5 | Add step (bottom sheet), validation errors, discard changes, delete recipe, delete step |
| film_quick_note_page.dart | 7 | New roll form, format error, invalid file, small images warning, import preview, duplicate handling, duplicate recipe confirm |
| roll_detail_page.dart | 2 | Share shot selection, delete roll |
| reciprocity_calculator_page.dart | 3 | Manage profiles (bottom sheet), add/edit profile, delete profile |
| developer_page.dart | 2 | Clear all logs, delete entry |
| timer_running_page.dart | 1 | Exit timer |
| darkroom_timer_page.dart | 1 | Duplicate recipe confirm |
| shot_page.dart | 1 | Image too small |
| settings_page.dart | 1 | About dialog |
