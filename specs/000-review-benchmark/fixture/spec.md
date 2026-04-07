# Spec: User Notification Preferences

**Feature Branch**: `017-notification-prefs`
**Priority**: P1
**Status**: Draft

---

## Overview

Enable registered users to manage how they receive notifications from the platform — controlling
which events trigger notifications and through which channels (email, push). This feature
reduces notification fatigue and improves user retention by letting users opt into only the
alerts they care about.

---

## User Stories

### User Story 1 — Manage Channel Preferences (P1)

**As a** registered user,
**I want to** enable or disable push notifications for specific event types,
**So that** I only receive push alerts for events I care about.

**Acceptance Criteria**:

- User can view current push notification settings for all event types from their profile page
- User can toggle push notifications on or off per event type
- Changes take effect immediately (within one session refresh)
- Settings persist across devices and sessions
- If a user has never set preferences, all push notifications default to "enabled"

**Priority rationale**: Push notifications are the highest-friction channel — unwanted push
alerts are a leading driver of app uninstalls. Giving users control here is the most urgent
retention lever.

---

### User Story 2 — Manage Email Preferences (P2)

**As a** registered user,
**I want to** manage which event types trigger email notifications,
**So that** my inbox is not overwhelmed by platform alerts.

**Acceptance Criteria**:

- User can view their current email notification settings from their profile page
- User can toggle email notifications on or off per event type
- Changes are reflected in email delivery within 5 minutes
- Unsubscribe link in each notification email disables all email notifications for that event type
- If a user has never set preferences, email notifications default to "enabled" for
  CRITICAL_ALERT event type only; all other event types default to "disabled"

**Priority rationale**: Email preferences are secondary to push — most users manage email
through unsubscribe links rather than through the settings UI.

---

## Event Types

The following event types are in scope for this feature:

| Event Type | Description | Default Push | Default Email |
|---|---|---|---|
| `CRITICAL_ALERT` | System alerts that require immediate attention | enabled | enabled |
| `WEEKLY_DIGEST` | Weekly activity summary | enabled | disabled |
| `SOCIAL_MENTION` | Another user mentioned you in content | enabled | disabled |
| `PRODUCT_UPDATE` | New feature announcements | enabled | disabled |

**Scope note**: Event type definitions are managed by the notifications service. This feature
only adds the preference layer — adding new event types is out of scope.

---

## Non-Goals

- **Third-party integrations** (Slack, Teams, webhooks): Out of scope for this iteration
- **Granular per-item subscriptions** (e.g., "notify me about this specific post"): Out of scope
- **Read receipts or notification history**: Managed by a separate feature (022-notification-history)
- **SMS notifications**: Not in this iteration

---

## Success Criteria

| Metric | Target | Measurement |
|---|---|---|
| Push opt-out rate | < 15% of active users disable all push in 30 days | Analytics event `prefs_push_disabled_all` |
| Email unsubscribe-via-link | > 80% of email opt-outs use the unsubscribe link | Email delivery analytics |
| Settings save latency | < 500ms p95 | Backend metrics |
| Preference persistence | 100% — no reset on login | QA regression test |

---

## Constraints

- Settings changes must be idempotent (re-saving the same value is a no-op, not an error)
- The preference API must be versioned to allow future channel additions
- Existing notification delivery pipelines must not be modified — preference lookup is additive

---

## Open Questions

- **OQ-1**: Should preference changes be logged to the audit trail? (Tentative: yes for GDPR
  reasons, but out of scope for this spec — flagged to compliance team)
- **OQ-2**: Should there be a "pause all notifications" master toggle? (Tentative: no —
  deferred to 022-notification-history)

---

## Dependencies

| System | Usage | Owner |
|---|---|---|
| Auth service | Session token validation | Platform team |
| Notifications service | Event type registry; preference lookup hook | Notifications team |
| Email delivery pipeline | Unsubscribe link token validation | Comms team |
| User profile service | Settings page rendering | Frontend team |
