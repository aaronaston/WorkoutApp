# Gap Analysis: Current State vs Target State (As of 2026-02-26)

Target references:
- `readme.md`
- `docs/features/plan-your-workout-requirements.md`
- `docs/features/plan-your-workout-design.md`
- `docs/architecture/README.md`
- ADR/DDR records in `docs/decisions/`

Planning source of truth:
- GitHub milestone `First releasable`
- Labels `release:v1` and `release:vNext`
- Issue dependency links (`Depends on #<issue>`)

## 1) Core repeatability and trust
- Target: users can inspect, repeat, resume, and adjust prior sessions without content loss.
- Current: History and Session Detail flows exist; reliability is improving but still under active hardening.
- Gap: all repeat/resume/adjust entry points must preserve full structured workout content consistently.

## 2) AI refinement workflow quality
- Target: iterative pre-start AI refinement feels responsive and controllable.
- Current: generation and adjustment flows exist.
- Gap: stream-first behavior, interruption, and iterative context carry-forward need completion and polish.

## 3) Generation alignment with curated workout style
- Target: generated/refined plans follow canonical headings and movement patterns from the curated library.
- Current: function-calling generation works and produces usable candidates.
- Gap: stronger instruction customization defaults and prompt/policy tuning are needed for consistency.

## 4) Discovery and generation performance/relevance
- Target: planning and discovery are fast and consistently relevant for daily use.
- Current: unified discovery + generation orchestration is in place.
- Gap: initial generation must be stream-first, and latency/ranking/slow-provider reliability require a focused tuning pass.

## 5) HealthKit continuity (phone-first)
- Target: completed sessions from this app appear reliably in Health/Fitness.
- Current: model groundwork exists.
- Gap: permission handling, mapping, export, and retry behavior must be complete and validated.

## 6) Deferred (post first releasable)
- Timer-mode-specific execution UX (EMOM/interval/AMRAP/countdown).
- Rich in-session logging and longitudinal progress analytics.
- Watch/live session integration depth.
- Calendar-aware discovery context.
- External source import pipeline and other quality-of-life enhancements.

## Release Readiness Gate
The release gate is the GitHub release-readiness issue for milestone `First releasable`.
Use that issue for final checks, manual acceptance signoff, and explicit vNext deferrals.
