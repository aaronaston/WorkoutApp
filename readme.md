# Introduction

This project is for a workout mobile application.  The main job is to suggest workouts for the user and then help them track their progress through it.  The app provides a variety of tools to assist with the workouts.  Some workouts require EMOM timers etc.  Some require timed exercise and rest periods etc.  The app also helps the user track their progress and metrics over time.  The simplest tracking is a history of workouts (which workout on which day).  The app should help the user select a workout that is appropriate based on their history (e.g. if yesterday was a leg day, then today should be an upper body day).  The app should also allow the user to track metrics per workout time.  For example, if the workout involves a range of reps of weighted squats with an unspecified dumbbell weight, the app should allow the user to track how many reps at what weight.

# Features

## 1) Workout Discovery and Recommendations
**Goal:** Suggest appropriate workouts based on prior activity and recovery balance (e.g., avoid repeating leg day back-to-back).

**User story (hybrid):** As a user, I want the app to recommend a workout that fits what I did recently so I can keep a balanced routine.

**Functional requirements:**
- Provide a list of recommended workouts based on workout history, muscle group balance, and recency.
- Allow the user to override recommendations and pick any workout manually.
- Show a short explanation for each recommendation (e.g., "Upper body day because last workout was legs").

**Data/logic:**
- Track workout categories (e.g., legs, upper body, full body, cardio, mobility).
- Use a simple rules engine (initially) based on last N days of history.

**Out of scope (for now):**
- Personalized AI or advanced adaptive programming.

## 2) Workout Execution and Timing Tools
**Goal:** Provide in-workout tools to run time-based sessions like EMOMs, intervals, and rest timers.

**User story (hybrid):** As a user, I want timers and cues during a workout so I can stay on pace without external apps.

**Functional requirements:**
- Support standard timer modes: EMOM, AMRAP (timer only), interval (work/rest), and simple countdown/stopwatch.
- Allow configuring rounds, durations, and rest periods per workout.
- Provide in-workout prompts (vibration/audio) for interval boundaries.
- Allow pausing/resuming a workout session.

**Data/logic:**
- Timer configuration is saved as part of a workout template and/or session.
- Session state is recoverable if the app is backgrounded.

**Out of scope (for now):**
- Voice coaching and custom audio tracks.

## 3) Workout Logging and History
**Goal:** Maintain a log of completed workouts for tracking and future recommendations.

**User story (hybrid):** As a user, I want a history of workouts by date so I can review what I did and pick what to do next.

**Functional requirements:**
- Store each completed workout session with date/time, workout type, and duration.
- Provide a calendar or list view of past workouts.
- Allow viewing details of a past workout session.

**Data/logic:**
- History is stored locally on device (no accounts).
- Sessions are immutable once saved, except for a "notes" field.

**Out of scope (for now):**
- Cloud sync between devices or multiple profiles.

## 4) Exercise Metrics Tracking (Reps/Weights)
**Goal:** Capture performance metrics within a workout, including variable weights and rep counts.

**User story (hybrid):** As a user, I want to log weights and reps for each exercise so I can track progress over time.

**Functional requirements:**
- For each exercise, allow logging sets with reps and weight.
- Support ranges or "target reps" and record actual completed reps.
- Provide a simple summary of progress for the same exercise over time.

**Data/logic:**
- Exercise data is keyed by exercise name and workout session.
- Weight unit defaults to user preference (lbs/kg).

**Out of scope (for now):**
- Automatic estimation of 1RM or training max.

## 5) Workout Templates and Customization
**Goal:** Enable defining workouts that combine exercises, timers, and structure.

**User story (hybrid):** As a user, I want to build and edit workout templates so the app fits my routine.

**Functional requirements:**
- Create/edit workouts with a name, category, exercises, and optional timer configuration.
- Reorder exercises and sets within a workout.
- Duplicate a workout to create a variation.

**Data/logic:**
- Templates are stored locally and can be reused across sessions.

**Out of scope (for now):**
- Shared templates or public workout library.

## 6) Apple Health Integration (Exploratory)
**Goal:** Optionally sync workout summary data to Apple Health and/or read basic metrics.

**User story (hybrid):** As a user, I want workouts to appear in Apple Health so my overall activity history is complete.

**Functional requirements:**
- Ask for HealthKit permissions when enabling integration.
- Write workout summary (type, duration, energy if available).
- Optionally read heart rate during a session (future).

**Data/logic:**
- Integration is opt-in and can be disabled at any time.

**Out of scope (for now):**
- Full bidirectional sync of exercise-level details.

## 7) Apple Watch Companion (Exploratory)
**Goal:** Provide a watch experience for workout tracking and timers.

**User story (hybrid):** As a user, I want a watch app to start/track workouts and see timers without holding my phone.

**Functional requirements:**
- Start a workout session from the watch (or mirror one started on the phone).
- Show current interval/EMOM countdown and upcoming transitions.
- Support quick logging of sets/reps (basic input).

**Data/logic:**
- Sync session state between phone and watch.
- Use watch haptics for interval cues.

**Out of scope (for now):**
- Fully standalone watch-only workflows with no phone present.
