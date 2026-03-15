# Game Presets Design

## Overview

Organizers can save game configurations as reusable presets (max 5). When creating a new game, they can choose a preset and only enter date/time — or optionally tweak individual fields before proceeding. Presets store sport type, event type, location, max/min participants, visibility, and invitee list.

## Data Model

### `game_presets` table

| Column | Type | Notes |
|--------|------|-------|
| id | bigint PK | |
| organizer_id | bigint FK → users | |
| name | string, not null | Auto-generated: "Basketball (Game) / Central Court" |
| sport_type | integer, not null | Same enum as games |
| event_type | integer, not null | Same enum as games |
| location_id | bigint FK → locations | |
| max_participants | integer, not null | |
| min_participants | integer, not null | |
| visibility | integer, default: 0 | Same enum as games |
| timestamps | | |

Index: `(organizer_id)`.

### `game_preset_invitees` table

| Column | Type | Notes |
|--------|------|-------|
| id | bigint PK | |
| game_preset_id | bigint FK → game_presets | |
| user_id | bigint FK → users, nullable | For known users |
| username | string | Display name for known or unknown users |
| timestamps | | |

Index: `(game_preset_id)`, `(game_preset_id, user_id)` unique where user_id IS NOT NULL.

Preset limit (max 5 per organizer) enforced at model validation level.

## User Flows

### Flow 1: `/newgame` — Choose new game or preset

1. Bot shows: "Create a new game or use a preset?" with inline buttons:
   - `🆕 New game`
   - `📋 Preset: <name>` (one per preset, up to 5)
2. **New game** → existing 10-step FSM
3. **Preset selected** → preset flow (Flow 2)
4. If organizer has **no presets** → skips directly to normal game creation

### Flow 2: Create game from preset

1. Bot shows preset summary (sport, event type, location, max/min, visibility, invitees)
2. "Want to change anything?" → `✅ No, just set date/time` | `✏️ Change something`
3. **No** → calendar for date/time → game created
4. **Change something** → field menu (sport type, event type, location, max, min, visibility, invitees). Organizer picks field, edits via same UI as normal creation, returns to summary. Can edit more or proceed.
5. After date/time entered → game created
6. Invitee confirmation: "These players will be invited: @user1, @user2. Proceed?" → `✅ Yes` | `❌ No`
7. Yes → invitations sent. No → game created without invitations.

### Flow 3: Save as preset after normal game creation

1. After game created (normal flow), bot asks: "Save as preset?" → `✅ Yes` | `❌ No`
2. **Yes** + < 5 presets → saved with auto-generated name, confirmation sent
3. **Yes** + 5 presets → "Which preset to replace?" → list of presets as buttons
4. **No** → done

### Flow 4: `/presets` command + Settings entry point

Both lead to same preset management screen:
1. List of presets with inline buttons
2. Tap preset → full summary
3. Actions: `✏️ Edit` | `🗑 Delete` | `⬅️ Back`
4. **Edit** → field menu (same as Flow 2), pick field, edit, return to summary, save
5. **Delete** → confirmation → deleted

## FSM Integration

### New FSM steps for `/newgame` with presets:
- `choose_preset` — new game or preset selection
- `preset_summary` — summary + "change anything?"
- `preset_edit_menu` — field picker
- `preset_edit_<field>` — editing specific field (reuses existing UI)
- `preset_datetime` — date/time for preset game
- `preset_confirm_invitees` — invitee confirmation

### Post-game-creation save steps:
- `save_preset_prompt` — "Save as preset?" Yes/No
- `save_preset_replace` — "Which to replace?" (at 5 limit)

### Preset management steps:
- `preset_manage_list` — list view
- `preset_manage_view` — single preset details
- `preset_manage_edit_menu` — field picker
- `preset_manage_edit_<field>` — editing a field
- `preset_manage_delete_confirm` — delete confirmation

## Architecture

### New Service: `PresetService`
- `create(organizer:, game_data:, invitees:)` — create preset + invitees
- `update(preset:, attrs:)` — update preset fields
- `delete(preset:)` — destroy preset and invitees
- `build_game_data(preset)` — extract hash for `GameCreator.finish`
- `auto_name(data, locale)` — generate name like "Basketball (Game) / Central Court"

### New Command: `PresetsHandler`
- Registered as `/presets` command
- Also reachable from Settings → "Manage presets"

### Reuse
Existing UI builders (sport type keyboard, event type keyboard, location keyboard, calendar, visibility keyboard) are reused — wired into preset FSM steps.

## I18n

New keys under `bot.presets.*` for both `en` and `ru` locales covering all prompts, buttons, confirmations, and error messages.

## Edge Cases

1. **Deleted location** — warn organizer, ask to pick new one during game creation
2. **User left bot** — silently skip during invitation; keep in preset for future
3. **Relaunch flow** — no save-as-preset prompt (relaunch has its own shortcut)
4. **Cancel during preset flow** — clear FSM state, preset unchanged
5. **Settings entry** — `settings:presets` callback routes to `PresetsHandler`
