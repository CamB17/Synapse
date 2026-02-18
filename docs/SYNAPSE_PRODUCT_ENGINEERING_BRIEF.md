# Synapse — Product + Engineering Intent Brief

## Purpose & Vision

Synapse is a calm daily operating system that reduces mental load.
It exists to help busy people (parents, students, builders) stop holding life in their head and instead rely on one lightweight system to remember, commit, and finish.

Synapse is not a project manager, not a kanban tool, and not a traditional todo list.
It is a daily control panel that supports three repeat loops:

1. Capture (when something pops up)
2. Commit (choose what matters today)
3. Clear (finish and reflect)

Success metric:

`Does opening Synapse reduce stress and create momentum?`

Emotional tone: Calm + Motivating

- Calm: low cognitive load, no clutter, no guilt.
- Motivating: subtle positive feedback, momentum cues, "small wins stack."

Never loud, never gamified, never a dashboard of noise.

## Core Product Identity

What Synapse is:

- A daily performance board for real life
- A system for habits + small commitments + focus tracking
- A tool that keeps users grounded and consistent

What Synapse is not:

- A backlog/task manager with endless lists
- A long scroll of completed todos
- A productivity "second brain" with complex modules (projects, finances, kanban)

## Primary Screens & Their Jobs

### 1) Today (the control board)

Goal: answer "How am I doing today?" in 2 seconds.

Today structure:

- Status Header: X / 5 cleared (daily cap), focus minutes, thin progress line, short status line ("Momentum building." / "Strong finish.").
- Daily Rituals: habits presented compactly (identity loop).
- Commitments: remaining tasks for today only (no backlog).
- Board Clear state: supportive empty state.
- Completed Today tile: summary only (for example "11 actions"), tap to review in a sheet. No long completed list on the dashboard.
- Daily Insight: one subtle line to reinforce calm motivation.

Key principle: Today should never feel like a todo app. It is a board, not a list.

### 2) Inbox (capture & triage)

Goal: frictionless capture when something pops into your head.

Inbox rules:

- Quick capture is fast and forgiving.
- Items are uncommitted.
- Primary action: Commit to Today (if space under cap).
- Inbox should be calm, not another list manager.

### 3) Focus (execution support)

Goal: let users focus without switching apps.

Focus rules:

- Focus sessions attach to a task.
- Focus can be used with or without a task, but task-tied focus is ideal.
- Sessions roll up into Review.

### 4) Review (reflection, not a report)

Goal: show simple weekly evidence without shame.

Review shows:

- Weekly chart (focus minutes/day)
- KPIs: focus time, sessions, tasks cleared, habit days
- Highlight: best day
- Calm empty states when no data exists

Review should feel like a quiet truth screen.

## Data Model Intent (High Level)

### TaskItem

- States are intentionally simple: `inbox`, `today`, `completed`.
- Today has a cap (currently 5) to encourage intentionality.
- Completed tasks are visible via "Completed Today" sheet, not a giant scroll.

### Habit

- Daily completion + streaks reinforce identity.
- Habits live on Today (Daily Rituals) as a first-class loop.

### FocusSession

- Records `startedAt`, `endedAt`, and `durationSeconds`.
- Review computes weekly focus and trends.
- UI should be robust to older sessions missing duration; fallback logic allowed.

## Design / UX Pillars

### Low mental load

- Minimal choices
- No dense lists
- Clear hierarchy

### Intentionality

- Daily cap for Today commitments
- Inbox separate from Today
- User commits, not dumps

### Controlled delight

- Subtle micro-interactions (completion, habit check, toast)
- Calm encouragement lines
- No confetti, no loud gamification

### Playfully premium (B + C)

- Light-first theme, warm surfaces, indigo accent
- Structured geometric cues + tiny whimsy
- Optional brand mascot later, but it must not add clutter

## Non-Goals (Guardrails)

- No Projects / Kanban / Finance modules
- No complicated tagging system
- No infinite backlog UI
- No productivity guilt mechanics
- No todo-app patterns like giant completed history on the main screen

## Current Phase & Next Phase

Current state:

- Phases 1-3 implemented (core loop, habits, review).
- Phase 4 (theme + brand layer) is in progress and includes dashboard polish: Today is a board, completed list is summarized.

Next phase focus:

- Phase 4.2 — Brand polish + engagement
- Consistent iconography rules
- Micro-delight moments (task complete + habit complete)
- Illustration/empty-state system (light, minimal)
- Tab bar final polish
- Finalize typography + spacing tokens across screens

## Alignment Checks

Use these questions while indexing and reviewing changes:

1. Does Today remain a board (no long completed list)?
2. Is Inbox capture frictionless and separate from Today commitment?
3. Are tasks limited to inbox/today/completed with a daily cap?
4. Are habits visible and easy to complete (identity loop)?
5. Does Review reflect weekly evidence simply (no noisy dashboards)?
6. Are micro-interactions subtle (calm + motivating), not gamified?

If all are yes, implementation is aligned.
