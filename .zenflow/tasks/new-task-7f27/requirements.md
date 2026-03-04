# Product Requirements Document
## Telegram Sports Game Coordination Bot

---

## 1. Overview

A Ruby on Rails 7.x application exposing a Telegram bot (via webhook) that lets **organizers** schedule team-sport events and lets **participants** discover, join, and track those events. The bot operates in both private chats (DMs) and group chats.

---

## 2. Actors

| Actor | Description |
|---|---|
| **Organizer** | A registered user who creates and manages events. Requires explicit authorization. |
| **Participant** | Any Telegram user who interacts with the bot in a group or DM context. |
| **System** | Background jobs performing scheduled checks and notifications. |

---

## 3. Authorization Model

- A user becomes an **Organizer** after completing the `/start` flow and self-registering as one.
- The `users` table stores `telegram_id`, `username`, `first_name`, `last_name`, `role` (`:participant`, `:organizer`), `locale`, and `created_at`.
- Authorization is checked before any organizer-only command; unauthorized users receive a clear error message and a prompt to register as an organizer.

**Scope decision (explicit)**: The original requirement states "authorization required before creating a game." This is interpreted as: the user must have explicitly registered as an organizer (via `/start` → "Register as Organizer" flow) rather than being approved by an admin. Admin-approval workflow is explicitly out of scope for v1 (see §19). The `role` column defaults to `:participant`; the user upgrades to `:organizer` by choosing that option in `/start`. This keeps the authorization gate in place while deferring admin overhead to v2.

---

## 4. Commands

| Command | Scope | Role | Description |
|---|---|---|---|
| `/start` | Private | Any | Register user; show main menu |
| `/newgame` | Private | Organizer | Begin multi-step game creation FSM |
| `/mygames` | Private | Organizer | List own active events with management actions |
| `/archive` | Private | Organizer | List past/cancelled own events; allow relaunch |
| `/publicgames` | Private/Group | Any | Browse public active events with filters |
| `/settings` | Private | Any | Manage notification subscriptions, locale preference |

---

## 5. Game / Event Lifecycle

### 5.1 States

```
draft → active → [cancelled | completed → archived]
```

- **draft**: being created via FSM; not yet visible.
- **active**: published; accepting participants; visible in listings.
- **cancelled**: automatically cancelled by system if min-participant threshold not met 3 h before start; organizer notified, participants notified.
- **completed → archived**: event datetime has passed; moved to archive automatically.

### 5.2 Game Attributes

| Attribute | Type | Notes |
|---|---|---|
| `sport_type` | enum | basketball, football, volleyball, hockey, tennis, badminton, other |
| `event_type` | enum | game, training |
| `title` | string | Auto-generated: "{sport_type} ({event_type})", e.g. "Basketball (Game)" |
| `scheduled_at` | datetime | Future datetime; UTC stored |
| `location_id` | FK | References `locations` |
| `max_participants` | integer | Upper limit; excess → reserve |
| `min_participants` | integer | Lower limit; < this 3 h before start → auto-cancel |
| `organizer_id` | FK | References `users` |
| `status` | enum | draft, active, cancelled, archived |
| `visibility` | enum | public, private |
| `chat_id` | bigint (nullable) | Telegram group chat where event was created/published |
| `message_id` | bigint (nullable) | ID of the pinned poll message in the group |

### 5.3 Concurrent Event Limit

- An organizer may have at most **2 active events** simultaneously.
- On attempting to create a 3rd, the bot prompts: "You already have 2 active events. Please archive one before creating a new one." and shows inline buttons to archive an existing event.

---

## 6. Game Creation Flow (Multi-Step FSM)

Steps in order. Each step shows an inline keyboard or expects a text reply.

1. **Sport type** — inline keyboard: basketball, football, volleyball, hockey, tennis, badminton, other.
2. **Event type** — inline keyboard: Game | Training.
3. **Date & Time** — text input; format accepted: `DD.MM.YYYY HH:MM` or `DD/MM/YYYY HH:MM`. Bot validates future date. Locale-aware prompt.
4. **Location** — inline keyboard showing previously used locations + "Enter new location" option. If new, expect text input.
5. **Max participants** — text input; integer 2–100.
6. **Min participants** — text input; integer 1–(max_participants). Must be ≤ max.
7. **Visibility** — inline keyboard: Public | Private.
8. **Confirmation** — summary card with all fields; inline keyboard: Confirm | Cancel.

On confirmation, game moves to `active` state.

**FSM state storage**: Stored in Redis, keyed by `"fsm:#{telegram_user_id}"`, using the same Redis connection as Sidekiq. A single Redis instance therefore serves both job queues and wizard state — no dual-path fallback. See §11 for job adapter rationale.

---

## 7. Participant Management

### 7.1 Voting

Each active event published in a group displays an inline keyboard message:
- **Going** — adds to active participant list (if < max_participants) or reserve list.
- **Maybe** — recorded but does not count toward limits.
- **Not Going** — removes from participant list / reserve (if previously voted Going/Maybe). *(Scope addition beyond original requirements: original spec only defined "Going" and "Maybe". "Not Going" is included as essential UX — without it there is no way to withdraw a Going vote. This is treated as an implicit requirement.)*

Toggling "Going" → "Not Going" frees a spot; the first person in the reserve list receives a DM: "A spot opened up in [event title] on [date]. Do you want to join? [Yes] [No]".

### 7.2 game_participants Schema

| Column | Type | Notes |
|---|---|---|
| `game_id` | FK | |
| `user_id` | FK | |
| `status` | enum | going, maybe, not_going, reserve |
| `invited_by_organizer` | boolean | true if organizer sent a direct invite |
| `notified_reserve` | boolean | Prevents duplicate reserve-promotion DMs |

### 7.3 Organizer Actions (via /mygames)

- View current participant list (going / maybe / reserve).
- Remove a participant manually (they receive a DM: "The organizer removed you from [event].").
- Vote themselves (Going / Maybe).
- Send personal invitations to specific users by Telegram username or user_id.

---

## 8. Invitations

- `invitations` table: `id`, `game_id`, `inviter_id`, `invitee_id`, `status` (pending/accepted/declined), `created_at`.
- Invitee receives a DM with inline keyboard: Accept | Decline.
- On Decline: organizer gets a DM notification: "[User] declined your invitation to [event]."
- On Accept: user added to participant list (or reserve if full).

---

## 9. Subscriptions & Notifications

- `subscriptions` table: `id`, `subscriber_id`, `organizer_id`, `created_at`.
- Participants can subscribe to specific organizers via `/settings`.
- When an organizer creates a **public** event, all subscribers receive a DM about the new event.
- Subscription management uses inline keyboard in `/settings`.

### `/settings` menu items (all users)

| Option | Description |
|---|---|
| Language / Locale | Toggle between `en` and `ru`; updates `users.locale` immediately |
| My subscriptions | View and unsubscribe from organizers (participants); no-op shown for organizers |
| Subscribe to organizer | Enter organizer's @username to subscribe (participants only) |
| My role | Shows current role; offers "Register as Organizer" button if currently `:participant` |

---

## 10. Locations

- `locations` table: `id`, `organizer_id`, `name`, `address` (nullable), `created_at`.
- Scoped per organizer for quick re-selection.
- Displayed as inline keyboard buttons during game creation.
- Global deduplication is out of scope for v1.

---

## 11. Background Jobs

| Job | Trigger | Action |
|---|---|---|
| `CheckGameThresholdsJob` | Every 5 minutes (cron) | Find active games where `scheduled_at` is between now and now+3h, check `going` count vs `min_participants`. If below threshold, cancel game, notify participants and organizer. |
| `ArchiveExpiredGamesJob` | Every 10 minutes (cron) | Find active games where `scheduled_at < Time.current`. Move to `archived` status. |
| `ReservePromotionJob` | Triggered on participant removal | Find first reserve participant for a game, send DM invite. |
| `SendInvitationJob` | Triggered on organizer action | Send DM to invitee. |

**Job adapter**: **Sidekiq** is used as the background job adapter. Redis is already required for FSM state storage (§6), so adding Sidekiq introduces no additional infrastructure dependency. GoodJob is explicitly ruled out — using Redis for FSM state while choosing GoodJob "to avoid Redis" would be contradictory.

**Per-job idempotency**:
- `CheckGameThresholdsJob`: before cancelling a game, re-check its status inside a DB transaction (`status == 'active'`). If it was already cancelled by a prior run, skip. This prevents double-notification on overlapping cron ticks.
- `ArchiveExpiredGamesJob`: uses `UPDATE … WHERE status = 'active' AND scheduled_at < NOW()` — idempotent by nature.
- `ReservePromotionJob`: checks `notified_reserve = false` before sending the DM, then sets it to `true` within the same transaction. Duplicate job enqueues are safe.
- `SendInvitationJob`: checks `invitations.status == 'pending'` before sending; skips if already accepted/declined.

---

## 12. Public Game Listing & Filters

`/publicgames` presents an inline-keyboard-paginated list of public active events.

**Filter options** (applied via callback queries):
- Sport type
- Location (by name)
- Organizer (by username)

Each event card shows: title, date/time, location, organizer, current participant count / max.

---

## 13. Archive & Relaunch

`/archive` shows organizer's past/cancelled events. Each entry has a **Relaunch** button.

Relaunch flow:
1. Confirm sport type, event type, location (pre-filled from archived event).
2. Enter new date & time.
3. Confirm → creates new `active` game copying `sport_type`, `event_type`, `location_id`, `max_participants`, `min_participants`, `visibility`, and `organizer_id` from the archived event.

**Participant list**: always starts **empty** on relaunch. No participants are carried over from the archived event. The new event begins fresh collection.

---

## 14. Group Chat Support

- Organizer adds bot to a group.
- Organizer runs `/newgame` in the group (or in DM and selects a group to publish to).
- Bot posts the event card + voting inline keyboard in the group.
- All members can vote; their `user_id` is captured on first interaction (upsert into `users`).

**Assumption**: The bot must be granted "Send Messages" and "Pin Messages" permissions in the group to pin the event card. Pinning is attempted but failure is non-fatal.

---

## 15. i18n

- Supported locales: `en` (default), `ru`.
- User locale stored in `users.locale`; defaults to Telegram's `language_code`.
- All bot messages use `I18n.t(...)` with locale-specific YML files under `config/locales/`.

---

## 16. Admin Panel

A minimal Rails web admin (`/admin`) for internal oversight:
- List users, games, subscriptions.
- Manual status changes on games.
- Protected by HTTP Basic Auth (env-var credentials) for v1.

**Assumption**: Full admin UI (ActiveAdmin / Administrate) is out of scope. A set of simple controller actions with scaffold-style views is sufficient for v1.

---

## 17. Notifications Summary

| Trigger | Recipient | Message |
|---|---|---|
| New public event | Subscribers of organizer | Event announcement |
| Spot freed (reserve promotion) | First reserve participant | Invitation DM |
| Organizer direct invite | Invitee | Invitation DM |
| Invitation declined | Organizer | Decline notification |
| Participant removed | Removed participant | Removal notice |
| Event cancelled (auto) | All going participants + organizer | Cancellation notice |
| 3rd event attempt blocked | Organizer | Limit notice with archive prompt |

---

## 18. Non-Functional Requirements

- **Webhook mode** only (no polling).
- The app handles Telegram webhook `POST /telegram_webhook`.
- **Webhook security**: Telegram's `setWebhook` is called with a `secret_token` parameter. Every incoming webhook request must include the `X-Telegram-Bot-Api-Secret-Token` header matching `TELEGRAM_WEBHOOK_SECRET`. The controller verifies this before processing; mismatched requests return `403 Forbidden`.
- Rails credentials / ENV vars: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_WEBHOOK_SECRET`, `WEBHOOK_URL`, `DATABASE_URL`, `REDIS_URL`.
- All database operations wrapped in transactions where data integrity is critical.
- Idempotent webhook handling: `update_id` from each Telegram update is stored; duplicate `update_id` values are discarded without processing. (See per-job idempotency in §11.)
- Graceful error handling: unrecognized commands return a friendly fallback message.
- **Project context**: this is a greenfield Rails application; there is no existing codebase to audit.

---

## 19. Out of Scope (v1)

- Payment integration.
- Team management / roster persistence beyond per-game lists.
- Match results / scoring.
- Admin-approval workflow for organizer registration.
- Full-featured admin UI (ActiveAdmin).
- Multi-language game-type names beyond the enum key.
