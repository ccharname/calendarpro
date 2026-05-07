# Popover Density & Color Refinement Design

**Date:** 2026-05-07
**Scope:** Popover-only — does NOT touch menu-bar text, settings, event detail window
**Status:** Plan A locked, implementation pending

---

## 1. Background

### Symptom

After the FD-004 MeeGo relaunch, the calendar popover ships with the locked
visual tokens (12pt continuous squircle, 16% top→bottom gradient, top gloss,
1px inner rim, drop shadow / glow ring). The cells are visually correct, but
zheng reports the overall popover feels "傻大" — oafishly chunky — and the
color treatment leaves room on both readability and refinement.

Concretely:
- 16pt solar number on a 36pt cell is **44% of the short side**. Desktop
  reference points (Fantastical menu-bar dropdown, Notion calendar, Cron) sit
  at **30–36%**. At 44% the digit dominates the tile and crowds the lunar /
  badge subtitle.
- The 6×6pt grid spacing plus 2pt vertical padding inflates each row to ~38pt.
  Stacking 6 rows = 228pt of pure grid + 6 spacings + 1 weekday header ≈ 280pt
  in the middle of a 340pt-wide popover. Vertically dominant.
- The 8pt lunar / festival subtitle is below comfortable reading threshold for
  Chinese characters at standard system DPI.
- The popover background uses a 4% `accentColor` corner-to-corner gradient
  layered behind cells; in light mode this softens cell-to-bg contrast where
  the cell itself already runs an internal gradient.
- The today yellow (#FFCF40 light, #FFD75E dark) is the loudest swatch on the
  surface — saturated yellow against a near-white surface punches harder than
  the "playful icon tile" goal demands.

### Goal

Reduce visual weight of the calendar grid by ~25% without losing the MeeGo
玩具感 identity, and free vertical space for events / weather. Tighten color
palette for refinement without touching the locked MeeGo tokens (gradient
delta, gloss, rim, shadow / glow) beyond the scope listed in section 4.

### Non-goals

- Popover width change (stays 340pt — narrowing kills events list density,
  widening drifts away from menu-bar dropdown idiom)
- Cell aspect ratio change (stays roughly square)
- New badge geometry (capsule pills locked per
  `calendar_cell_meego_design.md` — LED dot route already rejected)
- Weather feature work (separate diagnostic patch)

---

## 2. Current vs. Proposed Tokens

### 2.1 Sizing

| Token | Location | Now | New | Why |
|---|---|---:|---:|---|
| Cell corner radius | `meegoCellCornerRadius` | 12 | **10** | Cell short side drops 36→32; keep ~31% N9 ratio (lower bound); avoids >40% capsule drift flagged in MeeGo memory |
| Cell minHeight | `CalendarDayCellView` content `.frame(... minHeight: 34)` | 34 | **30** | Saves 4pt × 6 rows = 24pt vertical |
| Cell vertical padding | `.padding(.vertical, 2)` | 2 | **1** | Pairs with minHeight reduction; total cell height drops 38→32 |
| Grid horizontal spacing | `Grid(horizontalSpacing: 6, …)` | 6 | **5** | 4-multiple compatible (5 rounds visually closest), cells breathe but aren't gappy |
| Grid vertical spacing | `Grid(…, verticalSpacing: 6)` | 6 | **5** | Same |
| Solar text font | `.font(.system(size: 16, …))` | 16 | **13** | Ratio 13/32 = 41%; closer to N9 icon-text and Fantastical menu-bar |
| Solar text weight (normal) | `day.isToday ? .semibold : .medium` | .medium | **.regular** | Reduces visual ink load on non-focal cells |
| Solar text weight (today) | `.semibold` branch | .semibold | **.bold** | Locks focal contrast despite smaller font |
| Subtitle font (lunar/badge) | `.font(.system(size: 8, …))` | 8 | **9** | Above CJK comfort threshold; only +1pt so layout stable |
| Weekday header font | `Text(symbol).font(.system(size: 12, …))` | 12 | **11** | Tracks new cell scale |
| Weekday header color | `.secondary` (when not weekend) | secondary | **`Color.primary.opacity(0.55)`** | Fixed opacity beats system semantic — `.secondary` becomes too bright in dark mode |
| Adjacent-month text opacity | 0.32 (multiple branches) | 0.32 | **0.42** | Current is too faded to scan at a glance |

#### Resulting layout math

```
Popover width                            340  (unchanged)
Inner content (after 16pt h-padding)     308
Week-num gutter                           20
Horizontal spacing × 6                    30  (was 36)
Cell width = (308−20−30)/7              ≈ 36.9pt  (≈37, was 36)
Cell height (minHeight 30 + 1pt vpad×2)  32  (was 38)
6 rows × 32 + 5 v-spacing × 5            217  (was 264)
+ weekday header row                    +~16
Grid total                              ~233 (was ~280; saves ~47pt)
```

The freed ~47pt flows to events list (currently `maxHeight: 200` — can stay
at 200, but the popover total height is cut by the same amount when no events
are pinned, making the surface feel less monolithic).

### 2.2 Color

| Token | Location | Now | New | Why |
|---|---|---|---|---|
| Today fill (light) | `cellBaseColor` today branch | `#FFCF40` (1.0, 0.812, 0.251) | **`#F2C04D`** (0.949, 0.753, 0.302) | −7% saturation + slight value drop = warmer amber, less screaming |
| Today fill (dark) | same | `#FFD75E` (1.0, 0.843, 0.369) | **`#F2CB5A`** (0.949, 0.796, 0.353) | Mirror desaturation; dark already feels softer so smaller delta |
| Today badge pill (light) | `todayBadgeView` | `(0.95, 0.6, 0.1)` orange | unchanged | Badge already deep-orange against yellow tile — fine |
| Today badge pill (dark) | `todayBadgeView` | `(0.9, 0.75, 0.25)` | unchanged | Same |
| Today glow color | `glowColor` | tracks today fill | **track new today fill** | Consistency — uses same RGB tokens as `cellBaseColor` today branch |
| Popover bg gradient | `popoverBackgroundGradient` in CalendarPopoverView | `windowBackgroundColor → accentColor.opacity(0.04)` | **`windowBackgroundColor → windowBackgroundColor`** (flat) | Removes 4% accent tint that softens cell contrast in light mode |

The existing semantic colors (holiday red, working-adjustment blue, weekend
red, solar-term red, selected indigo, hover amber border) are NOT changed.
They already sit at appropriate contrast.

### 2.3 What stays locked

Per `calendar_cell_meego_design.md`, **none** of these change:

- 16% top→bottom gradient luminosity delta (8/8 light, 6/10 dark)
- Top gloss opacity ladder (today 40 / selected 30 / semantic 22 / normal 14)
- 1px inner top-edge rim (light 0.45, dark 0.22)
- Drop shadow ladder (resting 1.5pt blur 1pt y-offset; highlighted 6pt glow 0 y-offset)
- Capsule badge geometry (8pt text, 4pt h-pad, 2pt v-pad)
- Selected indigo tile, weekend / holiday / working-day semantics
- `matchedGeometryEffect` selection slide
- `.drawingGroup()` rasterization

The only locked-token deviation is corner radius 12→10. **Rationale**: cell
short side moves 36→32, and 12pt at 32pt short side = 37.5% which crosses the
40% "胶囊化" warning band per the MeeGo memory. 10pt at 32pt = 31.25%, sitting
right at the N9 baseline (27–30%) plus 1pp 玩具感 amplification — same design
intent as the original 35% choice, just preserved at the new scale.

---

## 3. Files Touched

| File | Change |
|---|---|
| `CalendarPro/Views/Popover/CalendarGridView.swift` | All sizing tokens + today yellow + adjacent-month opacity + weekday header opacity |
| `CalendarPro/Views/Popover/CalendarPopoverView.swift` | `popoverBackgroundGradient` stops |
| `docs/plans/2026-05-07-popover-density-and-color-design.md` | This doc |

No changes to: `PopoverSurfaceMetrics.swift` (340 width unchanged), event list,
weather strip, almanac strip, badge views, settings, view-model, controllers.

---

## 4. Validation

### 4.1 Compile

`xcodebuild -scheme CalendarPro -configuration Debug build` must succeed with
zero new warnings.

### 4.2 Visual QA matrix

zheng reviews the running popover in 4 states (showDayEventDots was removed
in FD-004, so the original 8-state matrix collapses to 4):

|  | Light | Dark |
|---|---|---|
| weekStart=Mon, highlightWeekends=on | screenshot | screenshot |
| weekStart=Sun, highlightWeekends=off | screenshot | screenshot |

Specific things to eyeball:
- Cells no longer feel "傻大"; digit reads as label not as poster
- Lunar / festival subtitle legible without squinting
- Today tile reads warm not screaming yellow
- Adjacent-month dates dim but scannable
- No regression in MeeGo identity (gradient + gloss + rim + glow still
  visible; tile still reads as "3D 玩具瓷砖")

### 4.3 Pre-existing tests

Existing regression tests touch click → date selection and stale-data guards;
none of those care about font size or padding. Should remain green.

`MonthGridCacheTests`, `DateFormattersTests`, `Calendar*RegressionTests`,
`PopoverHeader*Tests` all expected to pass unchanged.

The pre-existing `ClockRenderServiceTests.testTextImageRendererUsesTemplateImageForDefaultStyle`
remains broken (FD-004 base condition, not introduced by this work).

---

## 5. Followups Out of Scope

- **Weather "消失" regression**: separate diagnostic patch — add DEBUG
  `print` instrumentation in `refreshWeather` flow, run, capture cause
- Per-month 5-row vs 6-row height jitter (FD-004 known issue, deferred)
- Events list font scale review (this plan touches only calendar grid)
- Popover-to-detail-window sizing harmonization

---

## 6. Rollback

Single commit per concern (sizing in one, color in one, gradient drop in
one) so any of them can be reverted independently if zheng wants to keep
some refinements but not others.

---

## 7. Phase-2 Refinements (after first eyeball)

After the first build / relaunch (PID 36578), zheng reviewed the popover and
called out three more cuts. These are folded in the same patch series rather
than a follow-up plan:

| Concern | Token Δ | Rationale |
|---|---|---|
| Holiday cell weight too high vs. today | `semanticBaseColor`: light red `0.18→0.12`, dark red `0.72→0.62`; light blue `0.18→0.12`, dark blue `0.78→0.68` | Stack of base + 16% gradient + gloss meant 0.18 read as ~22-25% panel saturation; today amber should remain the visual focus |
| 劳动节 / 端午节 subtitle truncating | Subtitle logic: holiday/workday cells return `lunarText` (was holiday name) | "休"/"班" pill already conveys status — subtitle name was redundant + minimumScaleFactor was kicking in on 3-char names |
| Header "2026 年 五月" oversize | `.title3 .semibold` → `.system(size: 14, weight: .medium)` | Visual band stays the same (28pt pill height dominates) but the ink load drops, harmonizing with new 13pt cell scale |
| Events list under-fed | `EventListView .frame(maxHeight: 200)` → `240` | Returns the ~40pt freed by cell tighten back to information density rather than just shortening popover |

Also: **weather "消失" was transient** — relaunching the app restored it
(weather strip rendered with 19° / 北京市 first try). No code root cause; the
DEBUG `print` instrumentation added during diagnosis is removed in the same
patch series. If it recurs, re-add the instrumentation block from git history.

### Phase-2 file impact

| File | Change |
|---|---|
| `CalendarPro/Views/Popover/CalendarGridView.swift` | semanticBaseColor opacity drop; subtitle switch logic |
| `CalendarPro/Views/Popover/MonthHeaderView.swift` | year/month label font |
| `CalendarPro/Views/Popover/CalendarPopoverView.swift` | EventListView maxHeight 200 → 240 |
| `CalendarPro/Views/RootPopoverView.swift` | Strip 8x DEBUG print() blocks added during weather diagnostic |
