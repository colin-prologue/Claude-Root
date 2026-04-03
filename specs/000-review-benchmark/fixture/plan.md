# Implementation Plan: User Notification Preferences

**Branch**: `017-notification-prefs` | **Date**: 2026-03-15 | **Spec**: [spec.md](spec.md)

## Summary

Build the preference storage and retrieval layer for user notification settings. Users can
toggle push and email notifications per event type. Preferences are stored per user in the
database, with defaults applied at read time when no preference record exists. The API is
exposed via a REST endpoint consumed by the profile settings page.

## Decision Records

| # | Type | File | Title | Status |
|---|---|---|---|---|
| ADR-012 | Decision | ADR_012_preference-api-versioning.md | Preference API Versioning Strategy | Accepted |
| ADR-015 | Decision | ADR_015_default-preference-resolution.md | Default Preference Resolution at Read Time | Accepted |

## Technical Context

**Language/Version**: TypeScript 5.3 / Node.js 20 LTS
**Framework**: Express 4.18
**Database**: PostgreSQL 15 (existing shared instance)
**Testing**: Vitest 1.3
**Package manager**: npm

## Stack

| Layer | Technology | Version |
|---|---|---|
| Language | TypeScript | 5.3 |
| Framework | Express | 4.18 |
| Database | PostgreSQL | 15 |
| Testing | Vitest | 1.3 |
| Package manager | npm | — |

---

## Project Structure

```text
src/
  modules/
    notification-prefs/
      prefs.controller.ts        ← REST endpoint handlers
      prefs.service.ts           ← Business logic, default resolution
      prefs.repository.ts        ← Database access (PostgreSQL)
      prefs.types.ts             ← TypeScript interfaces (UserPref, EventPref, etc.)
  middleware/
    auth.middleware.ts           ← Token validation (existing — no changes)
tests/
  notification-prefs/
    prefs.service.test.ts        ← Unit tests — default resolution, idempotency
    prefs.controller.test.ts     ← Integration tests — API contract, validation
```

---

## Data Model

### `user_notification_preferences` table

```sql
CREATE TABLE user_notification_preferences (
  id           SERIAL PRIMARY KEY,
  user_id      INTEGER NOT NULL REFERENCES users(id),
  event_type   VARCHAR(50) NOT NULL,
  push_enabled BOOLEAN,
  email_enabled BOOLEAN,
  updated_at   TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, event_type)
);
```

**Default resolution**: When no row exists for `(user_id, event_type)`, defaults are applied
at read time in `prefs.service.ts` — no row is written for defaults. This avoids backfill
migrations when default values change (ADR-015).

**Nullable columns**: `push_enabled` and `email_enabled` are nullable. A NULL value means
"use platform default." Explicit `true`/`false` overrides the default. This pattern lets a
third channel be added later by adding a new nullable column.

---

## API Design

### `GET /api/v1/preferences/notifications`

Returns the current user's notification preferences for all event types.

**Response**:
```json
{
  "preferences": [
    {
      "event_type": "CRITICAL_ALERT",
      "push_enabled": true,
      "email_enabled": true
    }
  ]
}
```

### `PUT /api/v1/preferences/notifications`

Saves preferences for one or more event types.

**Request body**:
```json
{
  "preferences": [
    {
      "event_type": "WEEKLY_DIGEST",
      "push_enabled": false,
      "email_enabled": false
    }
  ]
}
```

**Response**: `200 OK` with updated preferences.

---

## Rate Limiting

To prevent preference-update spam (e.g., rapid toggles in a scripted loop), the service will
implement rate limiting using Redis as the token bucket store. Rate limit parameters:

- **Limit**: 30 updates per user per minute
- **Scope**: per-user (keyed on `user_id`)
- **Enforcement**: `rate-limiter-flexible` library, configured at application startup

Redis connection details will be read from `REDIS_URL` environment variable. The Redis
instance is shared with the session service (already provisioned).

---

## Error Handling

| Scenario | HTTP Status | Error Code |
|---|---|---|
| Invalid event_type in request | 400 | `INVALID_EVENT_TYPE` |
| Malformed preference value (non-boolean) | 400 | `INVALID_PREFERENCE_VALUE` |
| Database write failure | 500 | `PREFERENCE_SAVE_FAILED` |
| Unauthenticated request | 401 | `UNAUTHENTICATED` |

---

## Implementation Order

### Phase 1: Data Layer

1. Write database migration: create `user_notification_preferences` table
2. Write `prefs.repository.ts` — `getPreferences(userId)`, `upsertPreferences(userId, prefs[])`
3. Write `prefs.types.ts` — TypeScript interfaces

### Phase 2: Business Logic

4. Write `prefs.service.ts` — default resolution, idempotency check, preference merge
5. Write unit tests for service layer

### Phase 3: API Layer

6. Write `prefs.controller.ts` — GET and PUT handlers, request validation
7. Register routes in `app.ts`
8. Write integration tests for API endpoints

### Phase 4: Infrastructure

9. Add Redis setup and `rate-limiter-flexible` configuration
10. Wire rate limiter to... `GET /api/v1/preferences/notifications`

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|---|---|---|
| Default resolution logic produces incorrect defaults at read time | MEDIUM | Unit tests cover all four event types and the NULL vs explicit override distinction |
| Preference update loses data under concurrent writes | LOW | PostgreSQL `ON CONFLICT DO UPDATE` with row-level locking |
| Nullable column pattern creates confusion for future engineers | LOW | ADR-015 documents the rationale; code comments reference it |
| Redis connection failure causes rate-limit middleware to block requests | LOW | Configure Redis connection pool with timeout; fail-open on Redis unavailability |
