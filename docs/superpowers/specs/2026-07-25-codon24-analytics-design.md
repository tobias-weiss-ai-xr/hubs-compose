# Codon 24: Analytics Dashboard — Design

## Overview

Real-time analytics dashboard for chemistry VR labs. Teacher view shows room stats, student progress overview, and quiz results. Student view shows own progress summary.

## Architecture

Same pattern as Codon 22/23 — extends existing REST endpoint + channel events for live data. No new DB tables or Ecto schemas — all data from existing `hub`, `user_progress`, and `quiz_answers` tables.

- **Reticulum (Elixir)**: Extend `GET /api/v1/hubs/:id/analytics` in hub_controller.ex to include student progress + quiz aggregates
- **Hubs (JS)**: hub-channel.js wrapper method + AnalyticsDashboard React component

## Data Sources

| Source | Fields | Used For |
|--------|--------|----------|
| `hub` | `name`, `current_occupants`, `max_ccu_24h` | Room stats |
| `user_progress` | per-student entries | Student completion %, time spent |
| `quiz_answers` | per-student answers with `correct` flag | Quiz summary per element |

No new DB tables. No new Ecto schemas.

## REST Endpoint

Extend `GET /api/v1/hubs/:id/analytics` response to include:

```json
{
  "room": {
    "name": "...",
    "current_occupants": 5,
    "max_ccu_24h": 12
  },
  "students": [
    {
      "account_id": 123,
      "identity_name": "Student A",
      "total_elements": 8,
      "completed": 5,
      "total_time_spent_ms": 450000,
      "quiz_avg_score": 75
    }
  ],
  "quiz_summary": {
    "total_quizzes": 3,
    "total_participants": 5,
    "average_score": 70
  }
}
```

Endpoint authorization: teacher-only (same `can?(:update_hub, hub)` check).

## Real-time Updates

No new channel events. Existing events feed the dashboard:
- `progress_updated` → refresh student progress cards
- `quiz_started`/`quiz_ended` → refresh quiz summary

## Frontend

### hub-channel.js
One new method:
- `fetchAnalytics()` — calls `GET /api/v1/hubs/:id/analytics`

### AnalyticsDashboard.js (React component)
- Colleged inside same pattern as the existing sidebar panels in ui-root.js
- Teacher view: room stats card, student list with completion %, quiz summary
- Student view: own progress (reuses ProgressPanel's StudentView logic)
- Auto-refreshes on real-time events (`progress_updated`, `quiz_ended`)

## Files to Create/Modify

### Reticulum (`hubs-cloud`)
- `lib/ret_web/api/v1/hub_controller.ex` (modify — extend analytics endpoint)

### Hubs (`hubs`)
- `src/utils/hub-channel.js` (modify — add 1 method)
- `src/react-components/room/AnalyticsDashboard.js` (new)
- `src/react-components/room/AnalyticsDashboard.scss` (new)
- `src/react-components/ui-root.js` (modify — wire into sidebar + menu)
