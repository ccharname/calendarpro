# Changelog

All notable changes to CalendarPro will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0-beta.3] - 2026-05-06

First fork release from `ccharname/calendarpro`. Forked from `yelog/calendar-pro` at v0.1.4-beta.1 (`318493a`). Three themes: Nokia/MeeGo-style calendar UI, render-path performance overhaul, and a redesigned events/reminders panel.

### Added

- **MeeGo-style calendar cells**: 12pt continuous squircle (≈35% of short side, N9/Harmattan iconography), 16% top-to-bottom luminosity gradient, glossy top-half overlay, 1px inner highlight rim, outer drop shadow on resting tiles, colored glow on highlight states (today / selected / hovered)
- **Today / holiday / workday / solar-term capsule pills** in the cell top-trailing corner, single-pill priority when today and holiday collide
- **Week-number gutter** on the calendar grid (ISO 8601 week-of-year, derived from each row's middle day so the digit is stable regardless of weekStart preference)
- **Variable month grid rows** (5 or 6) — months that fit in 5 rows no longer waste a row of next-month overflow
- **Today and overdue typography**: deep-amber day number and subtitle on the yellow tile for contrast; weekend day numbers in `#E04F5F` (light) / `#FF6B7A` (dark)
- **Events/reminders panel redesign**: 56pt min-height cards with uniform 12pt H / 8pt V padding, 14pt continuous squircle, top row [reminder-checkbox or color-dot · priority · title · metadata icons], bottom info row [calendar · location or end-time or `Overdue`]
- **Reminder context menu** (right-click): Toggle Completion, Delete
- **Priority indicators** (`!`, `!!`, `!!!` in red; single `!` in grey for low) inline before reminder titles
- **Overdue reminder treatment**: red time label, red 2pt leading accent strip, full opacity (overdue must pop, not fade), sorted to top of the list
- **Past / ongoing / future event states**: past completed at 0.5 opacity with `controlBackgroundColor × 0.6` tint and strikethrough, past events at 0.55 opacity, ongoing carries a 3pt accent-color stripe plus a soft 4pt accent glow
- **Now-marker** with subtle pill background (matching unfinished card background) on the timeline rail; aligned baseline with the gray hour labels above and below it
- `MonthGridCache` keyed on `(displayedMonth, selectedDate, weekStart, activeRegionIDs, enabledHolidayIDs, lunarTokenStyle, todayStartOfDay)` — no per-render rebuild of `CalendarDayFactory`
- `DateFormatters` infrastructure pooling instances behind a single API; ad-hoc `DateFormatter()` allocations cut from 30+ to 8
- Per-(day, timezone) memoization of `LunarDateDescriptor`; per-(region, year) cache for resolved holiday occurrences (invalidated on remote feed refresh)
- Background prewarming of lunar + holiday caches at app launch (covers current month ±1) so the first menu-bar click finds warm caches
- `solarDateKey` integer key on `CalendarDay` for formatter-free accessibility identifiers
- `selectionNamespace` + `matchedGeometryEffect` so the selected-day highlight slides between cells instead of fading off / on
- `.drawingGroup()` on the day cell to flatten the 6-layer ZStack into a single GPU-rasterized layer
- Regression test coverage: `MonthGridCacheTests` (key invalidation), `DateFormattersTests` (instance reuse), `RecurringReminderOccurrenceTests` (B10 lock), `TimeRefreshCoordinatorDayChangeTests` (B11 lock), `MonthGridCacheTests.testSelectedDateChangeReflectedInCellIsSelected` (click → selection regression lock)
- Design doc `docs/plans/2026-05-05-meego-relaunch-design.md` with full token tables; `MeegoCellPreview.swift` with 8-variant SwiftUI preview

### Changed

- Replace `LazyVGrid` with static `Grid` / `GridRow` for the calendar grid (non-lazy is appropriate for fixed 6×7 + week-number layout)
- Day-cell number font 13pt → 16pt (medium / semibold for today); lunar / holiday subtitle 9pt → 8pt
- Reduce day-number / lunar VStack spacing to 1pt — the 16pt line height already supplies the visual rhythm
- Drop redundant start time from inside event/reminder cards — left timeline lane already shows it; range events show only the end time as `→ HH:mm`
- Now-marker time label sits on the rail with the same font/baseline as gray hour labels (red color only)
- Per-group rail dots removed — the rail is just a 1pt connector line; the time label on the left and the card on the right are sufficient anchors
- Vacation-guide button demoted to secondary styling so the today button is the sole blue accent
- Footer Settings/Quit buttons forced to single-line inline `HStack` layout (was vertical Label, halving footer height)
- Spacing / font / corner-radius tokens snapped to a unified scale (4 / 8 / 12 / 16 / 24 spacing, 8 / 9 / 10 / 11 / 12 / 13 / 16 fonts, 12 / 14 / 16 radius); ~120 ad-hoc magic numbers fixed across 17 files
- Animation curves upgraded: fast feedback (press / hover / panel) `.easeOut` → `.snappy(0.15s)`; state transitions (completion, opacity, selected) `.easeInOut(0.2s)` → `.spring(response: 0.35, dampingFraction: 0.85)`
- `WeatherService.manualLocation` mutated via `updateLocation(_:)` instead of full struct reassignment (Swift 6 strict concurrency safety)
- `displayCalendar` cached statically (Mon-first / Sun-first variants), no longer rebuilt on each accessor
- `popoverBackground` LinearGradient hoisted to a static constant
- ScrollView in events panel gets an 8pt trailing inset so the macOS overlay scrollbar no longer overlaps card squircles
- Popover slide-down animation disabled — instant menu-bar pop
- Weekday header / lane gutter widths trimmed (timeLabelWidth 50 → 42, railWidth 12 → 10)

### Fixed

- Click on a calendar date now actually switches the events panel to that day. Two regressions: (1) `.onLongPressGesture(minimumDuration: 0.001)` on the cell silently swallowed the parent-level `.onTapGesture`; switched to `.simultaneousGesture(TapGesture())`. (2) `loadEvents` rejected fetched items via strict `Date ==` against `viewModel.selectedDate`; switched to `calendar.isDate(_:inSameDayAs:)`.
- Today pill placement: badge HStack uses `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)` so the pill anchors to the cell corner, not collapsing to ZStack center
- Holiday tile saturation lifted in light mode (`.red.opacity(0.08)` → `0.18`, same for blue) so the red and the today yellow read at comparable strength
- Week numbers vertically aligned with the day-number row (top-aligned + 7pt offset)
- Now-marker time label no longer wraps `HH:mm` to two lines on `11:16`-style values (timeLabelWidth tuned + `.fixedSize`)
- Day cell duplicate `.frame(maxWidth: .infinity, minHeight: 34)` and `.padding(.vertical, 2)` modifiers
- Reminder checkbox border uses calendar color (opacity 0.85) in incomplete state; completion glyph stays as `checkmark.circle.fill` for Apple-Reminders parity
- Rail-dot glyph for completed reminder group: was `checkmark.circle.fill` at 10pt with a baseline offset; now removed entirely (rail is dot-free) — moot once dots gone
- Overdue reminders no longer dim to 0.5 opacity (was a `timelineState == .past` catch-all that defeated the red strip / red time signal)
- `PopoverController.showPopover` honors `weekStart` preference when syncing day selection on open (was hardcoded to Sunday-first calendar)

### Removed

- `showDayEventDots` toggle and `MonthEventCountCache` stub (was wired into UI but never fetched data — would have misled users)
- `CalendarDay.eventCount` field

## [0.1.4-beta.1] - 2026-04-29

### Added

- add upcoming event indicator dot on menu bar
- support editing and deleting calendar items
- add calendar item creation
- add expandable weather details

### Fixed

- show recurring reminders on occurrence dates
- stabilize item composer and reminder filtering
- sync selected date after cross-day wake

## [0.1.4-beta.0] - 2026-04-24

### Added

- add current weather display with location fallback
- support date-aware forecasts for selected calendar dates
- add detailed weather metrics and city search
- add text styling and unpadded formats
- default menu bar text to bold
- show active item position in header
- unify refresh coordination

### Fixed

- dismiss popover when joining a meeting
- optimize refresh scheduling and stale state handling
- prevent stale weather when switching dates
- sync settings preview with live rendering

## [0.1.3] - 2026-04-22

### Added

- add locale-aware formatting and US/UK holidays
- localize settings and detail views
- finish user-facing copy cleanup
- add in-app language switch
- add participation status UI and responses
- expand meeting platform support
- show semantic metadata in event cards
- add cancelled event styling in timeline and detail view
- add 2021-2025 regional holiday data
- add vacation guide panel
- add teams join and chat actions
- unify refresh coordination
- add text styling and unpadded formats
- default menu bar text to bold
- show active item position in header

### Changed

- update README with schedule details and images

### Fixed

- default app language to chinese
- draw now marker through active card
- enable automatic update checks by default
- use template image to fix faded text on inactive displays
- reset to today after 30 seconds
- adjust top calendar navigation layout
- show source account in detail views
- show vacation guide year without digit grouping
- use yellow border for selected and hovered days
- reduce auxiliary panel transparency
- improve almanac strip readability
- remove teams chat action
- hide response state for read-only invites
- sync settings preview with live rendering

## [0.1.2] - 2026-04-09

### Changed

- update README with theme images, overview, and Chinese theme names

### Fixed

- prevent app exit and crash when closing settings

## [0.1.2-beta.0] - 2026-04-08

### Fixed

- prevent app exit and crash when closing settings

## [0.1.1-beta.2] - 2026-04-05

### Fixed

- align minute refresh to wall-clock boundary to prevent menu bar clock lag
- add system clock change notification for immediate menu bar resync
- restore manual settings window for reliable opening in menu bar app
- default update channel to stable

### Added

- add chineseFull date format (yyyy年MM月dd日)

## [0.1.1-beta.1] - 2026-04-04

### Added

- add stable and beta channel switching

### Fixed

- deliver system notifications on the main queue

## [0.1.1-beta.0] - 2026-04-02

### Added

- add Chinese almanac (宜忌) display in popover
- add weekend highlight with settings toggle
- use Chinese weekday symbols in calendar grid
- add week start day picker UI
- support solar terms in calendar
- support selecting detail text
- unify events visibility controls
- add dynamic height adjustment for event detail window
- add current-time event timeline
- enhance today cell styling with golden badge and background
- add PopoverDidClose notification listener and check on appear
- send PopoverDidClose notification when popover closes
- add lastClosedTime tracking and auto-reset logic to ViewModel
- add PopoverDidClose notification name

### Changed

- add design plans for removing weather feature
- add tyme dependency and update Xcode project settings
- add unified events settings design
- update appcast URLs to use raw.githubusercontent.com
- extract appcast feed URL logic for testability
- add project README
- add implementation plan for auto-reset-to-today
- add auto-reset-to-today feature design
- add 0.1.0 release entry [skip ci]

### Fixed

- prevent status item disappearance on display changes
- redesign current time marker layout
- simplify selected-day header summary
- place now marker by displayed time
- center resizable window on active screen
- position settings window near popover instead of screen center
- make entire button area clickable in footer buttons
- rebalance settings window layout

## [0.1.1] - 2026-04-08

### Added

- default launch-at-login to enabled on first launch
- add stable and beta channel switching
- add Chinese almanac (宜忌) display in popover
- add weekend highlight with settings toggle
- use Chinese weekday symbols in calendar grid
- add week start day picker UI
- support solar terms in calendar
- support selecting detail text
- unify events visibility controls
- add dynamic height adjustment for event detail window
- add current-time event timeline
- enhance today cell styling with golden badge and background
- add PopoverDidClose notification listener and check on appear
- send PopoverDidClose notification when popover closes
- add lastClosedTime tracking and auto-reset logic to ViewModel
- add PopoverDidClose notification name

### Changed

- reduce event timeline spacing for compact layout
- add design plans for removing weather feature
- add unified events settings design
- update appcast URLs to use raw.githubusercontent.com
- extract appcast feed URL logic for testability
- add project README
- add implementation plan for auto-reset-to-today
- add auto-reset-to-today feature design

### Fixed

- open Calendar.app via bundle identifier instead of calshow: URL scheme
- restore manual settings window for menu bar app
- align minute refresh to wall-clock boundary, add clock-change resync, and add chineseFull date format
- default update channel to stable
- deliver system notifications on the main queue
- use Xcode 26.3 for Swift 6.2 support
- use Xcode 16.4 for Swift 6.2 support
- prevent status item disappearance on display changes
- redesign current time marker layout
- simplify selected-day header summary
- place now marker by displayed time
- center resizable window on active screen
- position settings window near popover instead of screen center
- make entire button area clickable in footer buttons
- rebalance settings window layout

## [0.1.0] - 2026-03-31

### Added

- add Sparkle auto-update support and About settings page
- add app icon from calendar-pro.png
- show reminder detail panel on click with content-adaptive sizing
- open reminder in Reminders.app on click
- enhance event detail window with meeting join, attendees, and collapsible notes
- add MeetingLinkDetector for meeting URL extraction
- add configurable lunar display style (day/monthDay/yearMonthDay)
- auto-refresh on external calendar/reminder changes
- enable GitHub-hosted remote holiday feed
- add launch-at-login toggle to general settings
- 菜单栏样式下拉选项显示实时预览
- add year and month picker panels with clickable header
- add checkbox toggle to mark reminders as complete
- auto-scroll event list to ongoing or next upcoming item
- support chinese date format in menu bar
- open event detail in separate window
- improve popover interaction handling and event selection
- add reminders permission description and entitlement
- add CalendarItem enum to unify events and reminders
- add reminders fetching support to EventService
- add reminders settings UI to EventsSettingsView
- display menu bar icon on all screens
- integrate EventService and EventListView into calendar popover
- add date selection interaction to CalendarGridView
- create EventListView for event list display
- create EventCardView for event display
- create EventService for EventKit access
- add event and reminders settings to MenuBarPreferences
- add EventKit permission descriptions
- add today button, improve holiday styling
- add toolbar with settings and quit buttons

### Changed

- redesign settings with custom sidebar and summary cards
- replace TabView with NavigationSplitView sidebar layout
- restructure settings layout with ScrollView and grouped sections
- move lunar format selection to display tokens section
- simplify status bar and improve notes display
- improve event detail window styling
- simplify calendar groups sorting logic
- group calendars by source
- inject EventService via AppDelegate for shared instance
- remove redundant 'showsSeconds' toggle control

### Fixed

- simplify Settings scene and remove deprecated lunarDisplayStyle test param
- default notes to expanded and fix background card sizing
- prevent double event detail window close on popover dismiss
- close event detail window before closing popover
- hide style picker for lunar and holiday tokens
- remove duplicate style option for time token
- correct timer granularity when time style is full
- remove thousand separator from year display in month picker
- show lunar text for months crossing year boundaries
- scroll to last event when no future events today
- sort items by time-of-day instead of full date
- group same-time events into one card and add scroll to prevent overflow
- show lunar text instead of badge for working adjustment days
- align event detail window with popover content top
- fix reminders not showing in event list
- constrain event detail window height to screen bounds
- fix notes not fully displayed in event detail
- avoid clipping holiday badges
- avoid reminder fetch crash on launch
- menu bar style changes not reflecting immediately
- load events immediately after calendar authorization granted
- bring settings window to front when clicking settings button
- auto-grow popover height based on content, add max height for event list
