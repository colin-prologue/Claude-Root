# Tasks: User Notification Preferences

**Input**: Design documents from `specs/017-notification-prefs/`
**Branch**: `017-notification-prefs`
**Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md)

**Organization**: Tasks are grouped by phase to match the implementation order in plan.md.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)
- No application code — all deliverables are TypeScript source files and SQL migrations

---

## Phase 1: Data Layer

**Purpose**: Create the database schema and repository layer.

- [ ] T001 Write database migration `migrations/20260315_create_user_notification_preferences.sql`
- [ ] T002 Write `src/modules/notification-prefs/prefs.types.ts` — TypeScript interfaces: `UserPref`, `EventPref`, `ChannelState`, `PreferenceUpdate`
- [ ] T003 Write `src/modules/notification-prefs/prefs.repository.ts` — `getPreferences(userId)` and `upsertPreferences(userId, prefs[])` with PostgreSQL queries

---

## Phase 2: Business Logic (User Story 1)

**Purpose**: Core preference management for push notifications (User Story 1 — P1).

- [ ] T004 Write `src/modules/notification-prefs/prefs.service.ts` — preference read with default resolution, idempotency check, preference merge logic
- [ ] T005 Write `tests/notification-prefs/prefs.service.test.ts` — unit tests: default resolution for all four event types, NULL vs explicit override, idempotency (same value re-save)
- [ ] T006 Write `src/modules/notification-prefs/prefs.controller.ts` — GET handler for `GET /api/v1/preferences/notifications` with auth middleware wiring
- [ ] T007 Write `src/modules/notification-prefs/prefs.controller.ts` — PUT handler for `PUT /api/v1/preferences/notifications`, request validation, 400/401/500 error states
- [ ] T008 Register routes in `src/app.ts` under `/api/v1/preferences`

---

## Phase 3: Infrastructure (User Story 2 support)

**Purpose**: Redis setup for rate limiting, shared across User Stories 1 and 2.

- [ ] T009 Add `rate-limiter-flexible` and `ioredis` to `package.json`; configure Redis client at `src/config/redis.ts` reading from `REDIS_URL` environment variable
- [ ] T010 [P] Write `src/config/app.config.ts` — add `REDIS_URL` to environment config schema, with validation on startup
- [ ] T011 [P] Write `src/config/rate-limit.config.ts` — define rate limit parameters: 30 updates per user per minute, keyed on `user_id`; export `rateLimitConfig` object for middleware use

---

## Phase 4: User Story 2 — Email Preferences

**Purpose**: Extend preference management to email channel (User Story 2 — P2).

- [ ] T012 Write `tests/notification-prefs/prefs.controller.test.ts` — integration tests: GET returns merged defaults + stored prefs; PUT with valid body returns 200; PUT with invalid event_type returns 400; PUT without auth returns 401
- [ ] T013 Extend `prefs.service.ts` to handle email channel preferences: default resolution for email (CRITICAL_ALERT enabled only), merge logic for email alongside push
- [ ] T014 Write `tests/notification-prefs/email-prefs.test.ts` — unit tests: email default resolution (CRITICAL_ALERT enabled, all others disabled), email preference persistence
- [ ] T015 [P] Wire rate limiter middleware to `PUT /api/v1/preferences/notifications` — import `rateLimitConfig`, apply `RateLimiterRedis` as Express middleware before the PUT handler
- [ ] T016 [P] Add rate limiter middleware to `GET /api/v1/preferences/notifications` — read operations are also rate-limited at a higher threshold (100 reads/user/minute)

---

## Phase 5: Polish

**Purpose**: Final validation and documentation.

- [ ] T017 Run full test suite: `npm run test` — confirm all tests pass
- [ ] T018 [P] Update `src/app.ts` to add health check for Redis connection on startup: log warning (not error) if Redis unavailable, fail-open for rate limiting
- [ ] T019 [P] Update `src/app.ts` environment validation to require `REDIS_URL` in production; allow missing in development with in-memory fallback

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1**: No dependencies — start immediately
- **Phase 2**: T004 depends on T002, T003; T005 depends on T004; T006–T008 depend on T004
- **Phase 3**: T009 has no code dependency but should follow Phase 2 (sequencing by convention); T010 and T011 depend on T009
- **Phase 4**: T012 depends on T006, T007; T013 depends on T004; T014 depends on T013; T015 and T016 depend on T009 and T011
- **Phase 5**: T017 depends on all previous; T018 and T019 depend on T009

### Parallel Opportunities

```
# Phase 3 — config files can be written in parallel:
Task T010: Write src/config/app.config.ts
Task T011: Write src/config/rate-limit.config.ts

# Phase 4 — rate limiter wiring can be done in parallel:
Task T015: Wire rate limiter to PUT endpoint
Task T016: Add rate limiter to GET endpoint

# Phase 5 — app.ts updates can be done in parallel:
Task T018: Health check for Redis
Task T019: Environment validation
```

---

## Notes

- T001 (migration) must be reviewed by a DBA before being run in staging
- T009 introduces Redis as a new runtime dependency — infrastructure team must provision the instance before T015/T016 can be tested end-to-end
- T012 (integration tests for User Story 2's controller) covers the test contract for the email preference endpoint introduced in T013 — this is the integration coverage for email preferences
