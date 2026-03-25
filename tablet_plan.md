# Adaptive UI Plan: Phone + Tablet

## Current Issues

- Orientation locked to portrait only
- Home grid hardcoded to 2 columns (wastes space on 10"+ screens)
- Calculator pages are single-column full-width (stretched inputs on wide screens)
- List pages (recipes, rolls) are single-column
- Drawer navigation is fine for phones but could be persistent on tablets

## Options

### Option A: Responsive breakpoints (small effort)

Only adjust sizing and column counts based on screen width. No structural changes.

- Unlock orientation for tablets (keep portrait lock on phones only)
- Home grid: 2 cols on phone, 3 on small tablet, 4 on large tablet
- Calculator pages: constrain inputs to `maxWidth: 600` centered, so they don't stretch across a 10" screen
- List pages: 2-column card grid on wide screens
- Keep drawer navigation as-is

Pros: Minimal code changes, no architecture change, low risk
Cons: Still feels like a "big phone" on tablets, no landscape-specific layouts

### Option B: NavigationRail + max-width constraints (medium effort)

Replace the drawer with a permanent side NavigationRail on wide screens.

- Phone (<600dp): current drawer + stack navigation, portrait lock
- Tablet (>=600dp): persistent `NavigationRail` on left, no drawer, orientation unlocked
- Calculator pages: `ConstrainedBox(maxWidth: 560)` centered
- Home grid: adaptive column count
- Shared `AdaptiveScaffold` widget wraps all pages — picks drawer vs rail based on width

Pros: Feels native on tablets, one-thumb access to all tools, no hidden navigation
Cons: Every page needs to use the shared scaffold, moderate refactor

### Option C: NavigationRail + master-detail for lists (most effort)

Option B plus split-view layouts on wide screens.

- Everything from Option B
- Recipe list + recipe editor side-by-side on tablet landscape
- Roll list + roll detail side-by-side on tablet landscape
- Calculator pages: inputs on left half, results on right half (instead of pinned bottom) when landscape and wide enough

Pros: Best tablet UX, uses screen real estate fully, feels purpose-built
Cons: Significant refactor of list pages and calculators, more complexity to maintain

## Recommendation

**Option B** — biggest UX improvement per effort. NavigationRail makes tablet navigation feel native, max-width constraints prevent the "stretched phone" look. Option C's master-detail is nice but doubles the layout logic in list pages for marginal gain.
