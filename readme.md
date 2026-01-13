# Workout App (iOS) — Requirements

## Product Overview
This is an iOS workout application whose primary job is to help the user discover an appropriate workout, execute it with timing tools, and log performance so future recommendations improve. The app is self-contained (no accounts) and centered around an immutable, bundled knowledge base of expert-programmed workouts, with support for user-created templates and user-specific variants derived from that knowledge base.

## Target Users and Constraints
- iOS-only.
- Designed for personal use (you and your wife).
- No user accounts; data is stored locally on-device.
- Single-user per device for initial versions (no multiple local profiles).
- Offline-first for core features (knowledge base, templates, history); network is optional for external workout sources.
- Calendar access and LLM usage are opt-in and configurable.

## Core Principles
- **Workout discovery first:** the primary entry point is a “Workout Discovery” screen.
- **Explainable recommendations:** suggestions should include “why” and be tunable via simple preferences (not a black box).
- **Immutable source workouts:** knowledge base workouts are never edited in place; customizations produce user variants.
- **Robust display:** show workouts as written even if structured parsing is incomplete.
- **Optional LLM assistance:** free-form requests may use an external LLM (opt-in) to generate structured workout suggestions.

## Glossary (Working)
- **Knowledge base workout:** a bundled, read-only workout definition from `resources/workouts/*.md`.
- **Template:** a user-created workout definition stored locally.
- **Variant (derived template):** a user workout that references a base workout (usually from the knowledge base) plus overrides.
- **Session:** a single performed instance of a workout (from any source), recorded in history.
- **Rx (“as prescribed”):** the workout plan as written/recommended; users may scale/modify during execution.

## Core User Flow
1) Discover a workout (recommendations, search/browse, or free-form prompt)
2) Select a workout (knowledge base / template / external / generated)
3) Execute with timers and prompts
4) Log results (sets/reps/weight, notes, duration)
5) Review history and progress; feed back into future discovery

## Requirements

## Tooling (Local)
This repo includes a local pre-commit hook for Markdown linting, link checking, and spell checking. To enable it:

```bash
git config core.hooksPath .githooks
```

Install the required tools:

```bash
brew install lychee
npm install -g markdownlint-cli cspell
```

## Run in Simulator (CLI)
Use a generic iPhone simulator (first available iPhone), build, install, and launch:

```bash
UDID=$(xcrun simctl list devices available | rg -m1 "iPhone" | sed -E 's/.*\\(([0-9A-F-]+)\\).*/\\1/')
xcrun simctl boot "$UDID" || true
open -a Simulator

xcodebuild -project ios/WorkoutApp/WorkoutApp.xcodeproj -scheme WorkoutApp -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/WorkoutAppDerived
xcrun simctl install "$UDID" /tmp/WorkoutAppDerived/Build/Products/Debug-iphonesimulator/WorkoutApp.app
xcrun simctl launch "$UDID" com.example.WorkoutApp
```

### 1) Workout Discovery (Primary Screen)
**Goal:** Present good workout options for “today” based on history, context, preferences, and available sources.

**User story (hybrid):** As a user, I want the app to recommend a workout that fits what I did recently and what I feel like doing today so I can stay consistent without overtraining.

**Functional requirements:**
- The app starts on a “Workout Discovery” view (primary entry point).
- Provide a ranked list of recommended workouts.
- Allow the user to browse/search and pick any workout manually (not only recommended items).
- Support free-form discovery requests (natural language), e.g. “just move day” or “keep moving at ~60% effort”.
- Consider the following inputs in recommendation ranking:
  - recent activity (prior sessions, recency, balance)
  - calendar context from iOS Calendar (with permission), including day-of-week patterns and (optionally) event titles/metadata when useful for workout selection
  - user preferences (see below)
  - available sources (knowledge base, templates, external sources)
- Allow the user to tune recommendation inputs (preferences), including:
  - target duration (short/medium/long)
  - location (home/gym/away) and available equipment
  - focus/category preferences (strength, mobility, recovery, etc.)
  - source preferences (knowledge base only vs include personal templates; external sources on/off)
  - exclusions (temporarily exclude a category, exercise, or movement pattern)
  - balance rules (e.g., minimum rest days for legs; avoid repeating last category)
- Show a short explanation for each recommendation (e.g., “Upper body because last session was legs”).

**Data/logic:**
- Use a simple rules engine (initially) based on last N days of history and user preferences.
- Recommendation behavior should be explainable and tunable via simple weights/knobs (not a black box).
- If the user customizes a suggested workout, create a user-specific variant derived from the base workout.

**Free-form discovery (workout generation):**
- Accept a user prompt describing intent, constraints, and target intensity (e.g., “~60% effort”), and generate a workout suggestion.
- Generated workouts are expressed as a concrete workout plan (sections + exercises + prescriptions) with an Rx version.
- The generated plan must state why it matches the prompt and how it respects recent history (e.g., avoids repeated stress).
- Intensity targeting requires a user calibration model (initially simple), such as:
  - per-movement working weights or recent logged performance
  - RPE/RIR targets and time-domain constraints
- Allow the user to accept the generated workout, edit it into a template/variant, or regenerate with adjustments.
- Generation should be LLM-based (initially OpenAI models) and require explicit user configuration:
  - provide an API key (initial approach)
  - select model/provider when multiple are supported (future)
  - store credentials securely (iOS Keychain)
- If the LLM is not configured or network is unavailable, the app should degrade gracefully (e.g., prompt to configure, or offer non-LLM discovery paths).

**Privacy/permissions (discovery):**
- Calendar integration is optional; the user can disable it at any time.
- The user controls what data is shared with external LLMs, with category-level toggles (e.g., calendar context, history summaries, exercise logs, notes).
- Sharing defaults should favor convenience (“on” by default) but remain easy to disable globally or by category.

**Out of scope (for now):**
- Fully automated “adaptive programming” that changes long-term training plans without explicit user control.

### 2) Workout Knowledge Base (Bundled, Immutable)
**Goal:** Bundle a read-only library of expert-programmed workouts that the app can recommend, run, and use as the basis for user variants.

**Source of truth:**
- Workout definitions live in `resources/workouts/*.md` and are packaged with the app.
- The knowledge base is immutable at runtime (no in-app edits); updates happen only via app updates.

**Functional requirements:**
- Load and index all knowledge base workouts on-device.
- Provide fast browse/search by name and available tags/metadata (category, location, equipment when available).
- Display the canonical workout content as written (human-readable), even if structured parsing is imperfect.

**Parsing expectations (initial):**
- A workout file may include YAML front matter at the top; ignore it for workout content, but it may be used for metadata.
- The first `# Heading` is the workout name.
- `##` headings represent ordered sections/blocks (e.g., Prep, Push, Stretching).
- List items are exercises/steps; preserve full text but attempt to parse common patterns like:
  - `Exercise Name — <prescription>` (sets x reps, time, rest notes, per-side notes, etc.)
  - section headings that encode timer structure (e.g., `EMOM 40s on / 20s off`)

**Data/logic:**
- Each knowledge base workout has a stable identifier (e.g., derived from filename) for history, recommendations, and provenance.
- The app may keep a structured representation for filtering/recommendations, but must retain original Markdown for display/auditing.

**Out of scope (for now):**
- Authoring/editing knowledge base workouts on-device.

### 3) Templates, Variants, and Customization
**Goal:** Allow user-created workouts and user-specific modifications while keeping the knowledge base immutable.

**User story (hybrid):** As a user, I want to customize workouts (e.g., substitute exercises) so the app fits my needs and equipment.

**Functional requirements:**
- Provide two sources of workouts: the immutable knowledge base and user-created templates.
- Create templates from scratch or by copying a knowledge base workout.
- Support a “derived from” workflow: select a knowledge base workout and apply modifications to produce a personal variant.
- Allow edits to user templates/variants: name, category, exercises, and optional timer configuration.
- Support per-exercise substitutions (e.g., “pushups” -> “box pushups”) as a first-class customization.
- Reorder exercises and sets within a user template.
- Duplicate a user template to create a variation.

**Data/logic:**
- Knowledge base workouts are stored locally and never modified.
- User templates store either full standalone content or a reference to a base workout plus overrides (diff-like modifications).
- Variants retain provenance (base workout id and a base version/hash) so users can reset to base and understand what changed.

**Out of scope (for now):**
- Sharing templates publicly or with other users.

### 4) Workout Execution and Timing Tools
**Goal:** Provide in-workout tools to run time-based sessions like EMOMs, intervals, and rest timers.

**User story (hybrid):** As a user, I want timers and cues during a workout so I can stay on pace without external apps.

**Functional requirements:**
- Support standard timer modes: EMOM, AMRAP (timer only), interval (work/rest), and simple countdown/stopwatch.
- Allow configuring rounds, durations, and rest periods per workout.
- Provide in-workout prompts (haptics/audio where available) for interval boundaries.
- Allow pausing/resuming a workout session.
- Session state is recoverable if the app is backgrounded.

**Out of scope (for now):**
- Voice coaching and custom audio tracks.

### 5) Logging, History, and Metrics
**Goal:** Track what was done and how it went, and use that to inform discovery.

**User story (hybrid):** As a user, I want a history of workouts and performance metrics so I can see progress over time.

**Functional requirements:**
- Store each completed session with date/time, workout identity (source + id), and duration.
- Provide a calendar or list view of past sessions.
- Allow viewing details of a past session.
- Allow a notes field on a session.
- For each exercise, allow logging sets with reps and weight.
- Support ranges or “target reps” and record actual completed reps.
- Provide a basic progress view for an exercise across sessions (e.g., recent weights/reps).

**Data/logic:**
- Sessions are immutable once saved, except for notes and optional “fixup” edits (TBD).
- Weight unit defaults to user preference (lbs/kg).

**Out of scope (for now):**
- Cloud sync between devices or multiple profiles.
- Automatic estimation of 1RM or training max.

### 6) External Workout Sources (Optional)
**Goal:** Allow pulling workouts from user-configured external sources and using them in discovery and execution.

**Known sources to support (initial):**
- CrossFit WOD: `https://www.crossfit.com/wod`
- CrossFit workouts: `https://www.crossfit.com/workout`
- CrossFit Hero workouts: `https://www.crossfit.com/heroes`
- Other sources the user configures in preferences.

**Functional requirements:**
- External sources require network access; cache fetched workouts locally and tolerate offline mode gracefully.
- Imported workouts must be stored with provenance (source + URL + fetch date) and remain readable even if parsing is imperfect.
- Workouts discovered from external sources can be imported into the user’s library as editable templates/variants.

### 7) Integrations (Exploratory)

**Apple Health (HealthKit):**
- Ask for permissions when enabling integration.
- Write workout summaries (type, duration, energy if available).
- Optionally read heart rate during a session (future).

**Apple Watch companion:**
- Start a workout session from the watch (or mirror one started on the phone).
- Show current interval/EMOM countdown and upcoming transitions.
- Support quick logging of sets/reps (basic input).
- Use watch haptics for interval cues.

## Non-Goals (For Now)
- Accounts, login, or cloud sync.
- Social features (sharing, leaderboards).
- Recommendations (including LLM-assisted generation) that cannot be explained or tuned.

## Decisions (So Far)
1) Profiles: one user per device for now.
2) Calendar context: use the user’s iOS calendars (with permission), including event titles when they inform workout selection.
3) External sources: allow importing discovered workouts into the user library as editable templates/variants.
4) Free-form discovery: heavily LLM-based; start with OpenAI models using a user-provided API key.
5) Privacy: calendar integration is opt-in; LLM sharing should be user-toggleable with granular controls.
6) Calendar selection: include all calendars by default; allow user selection/exclusion.
7) Calendar-to-LLM sharing: controlled by an explicit user setting.
8) LLM sharing defaults: share enabled by default; allow opting out globally or by category.
9) LLM prompt scope: calendar context, history, exercise logs, notes, and future soreness/injury inputs are all eligible by default, with per-category opt-out.

## Open Questions
1) Default LLM detail level: send “summaries” where possible, or send full raw logs by default?
2) Category list: confirm the initial set of LLM share toggles (calendar, history summaries, exercise logs, notes) and whether “workout templates/variants” should be included too.
3) Redaction: should there be a user-editable “always redact” list (names/places) applied before sending calendar titles/notes to the LLM?
