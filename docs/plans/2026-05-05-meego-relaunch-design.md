# MeeGo Relaunch Design

**Date:** 2026-05-05
**FD:** FD-004
**Status:** M1 token lock (default values) — implemented in M5

---

## 1. Background

### Current State

`CalendarDayCellView` (in `CalendarGridView.swift`) uses a flat design:

- Solid `cellBackgroundColor` fill inside a `RoundedRectangle(cornerRadius: 10, style: .continuous)`
- `OFF` / `WRK` text Capsule pills in the top-trailing corner
- A `Today` text Capsule pill next to the pills
- Static 9pt subtitle for lunar/holiday text

The visual language is functional but lacks depth and identity. Compared to the iOS-era Nokia MeeGo icon grid (and the `lucky-toolkit` Calendar View it's inspired by), the cells read flat and the badge pills consume too much corner space for the information density they carry.

### MeeGo Target

The MeeGo icon language uses:

- Rounded squircle tiles (continuous corner radius ≈ 22% × short side)
- Gentle top-to-bottom luminosity gradient (~5% delta)
- 1px top white inner highlight stroke for depth
- Accent glow ring on active/hovered states
- Small LED indicator dots (4pt) instead of text badges

References:
- `/Users/zhengma/Developer/lucky-toolkit/main.js:760-989` — iOS-style calendar head + GitHub heat-map dots + squircle tiles
- `/Users/zhengma/Developer/lucky-toolkit/styles.css:592-810` — cell sizing, weekend colors, today/selected token colors

---

## 2. Visual Token Tables

### 2.1 Cell Shape

| Token | Value |
|---|---|
| Aspect ratio | 1:1 |
| Min height | 34pt |
| corner radius | 21% × short side = **7pt** (continuous squircle) |
| Corner style | `RoundedRectangle(style: .continuous)` |

### 2.2 Gradient

| Mode | Top color | Bottom color |
|---|---|---|
| Light | base | base −5% luminosity |
| Dark | base | base +5% luminosity (reversed) |

Computed via `Color.luminanceShift(_:)` using HSB conversion through `NSColor`.

### 2.3 Inner Highlight Stroke

| Token | Light | Dark |
|---|---|---|
| Width | 1px | 1px |
| Color | `white` | `white` |
| Top opacity | 0.18 | 0.08 |
| Bottom opacity | 0 | 0 |
| Direction | top → bottom gradient `strokeBorder` | same |

### 2.4 Outer Glow Ring

Only rendered on highlight states: **today**, **selected**, **hovered**.

| Token | Value |
|---|---|
| Blur radius | 6pt |
| Color | accent color for state, opacity 0.35–0.45 |
| Non-highlight | no shadow (radius 0) |

### 2.5 State Fill Colors

#### Today (yellow tile)

| Token | Light | Dark |
|---|---|---|
| Base hex | `#FFCF40` | `#FFD75E` |
| Swift | `Color(red:1.0, green:0.812, blue:0.251)` | `Color(red:1.0, green:0.843, blue:0.369)` |

#### Selected (non-today, indigo/violet)

| Token | Light | Dark |
|---|---|---|
| Base | `rgba(120,140,255,0.32)` | `rgba(140,160,255,0.30)` |
| Swift | `Color(red:0.471, green:0.549, blue:1.0).opacity(0.32)` | `Color(red:0.549, green:0.627, blue:1.0).opacity(0.30)` |

#### Holiday / statutory / public (red tint)

| Token | Light | Dark |
|---|---|---|
| Fill | `Color.red.opacity(0.08)` | `Color(red:0.26, green:0.09, blue:0.11).opacity(0.72)` |

#### Working adjustment day (blue tint)

| Token | Light | Dark |
|---|---|---|
| Fill | `Color.blue.opacity(0.08)` | `Color(red:0.07, green:0.18, blue:0.31).opacity(0.78)` |

#### Normal (in-month)

Fill: `.clear` (transparent on popover background).

### 2.6 LED Indicator Dot

Replaces `OFF` / `WRK` / `Today` Capsule text pills.

| State | Dot color (light) | Dot color (dark) | Priority |
|---|---|---|---|
| Today | white | white | 1 (highest) |
| Public / statutory holiday | `Color.red.opacity(0.88)` | `Color(red:0.86, green:0.25, blue:0.30)` | 2 |
| Working adjustment day | `Color.blue.opacity(0.88)` | `Color(red:0.17, green:0.50, blue:0.94)` | 3 |
| Solar term | `.orange` | `.orange` | 4 |
| None | no dot | no dot | — |

Dot size: **4pt diameter**, offset `(x: +1, y: −1)` from top-trailing corner.

### 2.7 Day Number Colors

| State | Light | Dark |
|---|---|---|
| In-month weekend | `#E04F5F` = `Color(red:0.878, green:0.31, blue:0.373)` | `#FF6B7A` = `Color(red:1.0, green:0.42, blue:0.48)` |
| In-month regular | `.primary` | `.primary` |
| Adjacent-month | `.secondary.opacity(0.32)` | `.secondary.opacity(0.32)` |

### 2.8 Animation Timings

| Event | Effect | Duration |
|---|---|---|
| Tap | scale 1.0 → 0.96 → 1.0 | 100ms (`easeOut`) |
| Hover ring fade | opacity 0 → 1 | 120ms (`easeInOut`) |

---

## 3. Day Event Dots

Off by default. Controlled by `MenuBarPreferences.showDayEventDots: Bool` (default `false`).

When enabled: up to 3 dots at `2pt` diameter, centered at the bottom of each cell, color `Color.secondary.opacity(0.55)`. Driven by `CalendarDay.eventCount: Int?` (nil = feature off or not yet fetched).

`MonthEventCountCache` fetches per-day counts via `EventService.fetchCalendarItems(for:...)` when the toggle is on.

---

## 4. Decisions and Rationale

### Why squircle (continuous corner radius)?

Apple's `RoundedRectangle(style: .continuous)` matches SF Symbols and app icon corners. The 21% corner radius (7pt on a 34pt cell) gives a softer, more organic tile than the old 10pt radius without approaching a full circle.

### Why gradient instead of solid fill?

Even a 5% luminosity delta between top and bottom creates implicit "front light" illusion — cells feel more physical, like icons on glass. Flat solid fills look like labels; gradients look like objects.

### Why LED dots instead of text pills?

`OFF` / `WRK` pills occupy ~18pt × 10pt of corner space. A 4pt dot carries the same semantic signal at 1/20th the visual weight. The holiday name and lunar text already appear in the cell subtitle — the badge just needs to signal "there's something here" at a glance.

### Why drop the "Today" text pill?

The yellow tile already distinguishes today. A white 4pt dot in the top-right corner confirms it for colorblind users. The redundant `Text("Today")` pill adds width without value.

---

## 5. Out of Scope / Deferred

- **Week-number gutter**: FD-004 does not include a week-number column. Deferred.
- **Hover→press cursor transition**: macOS pointer effects not needed for this milestone.
- **MonthEventCountCache live integration**: The cache class ships as a stub. Actual wiring to `RootPopoverView` and feeding `CalendarDay.eventCount` is deferred to a follow-up milestone. The dots row is plumbed but always empty until the cache is wired.
- **Snapshot / visual regression tests**: Day cell unit tests verify data→state mapping only. Screenshot regression deferred to M6 HITL QA.
- **Auto-detected working adjustment days for non-CN regions**: LED dot shows only when `LocaleFeatureAvailability.showWorkingAdjustmentDay` is true.
