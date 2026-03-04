# Technical Specification
## Telegram Sports Game Coordination Bot

---

## 1. Technical Context

| Concern | Choice | Rationale |
|---|---|---|
| Language | Ruby 3.2+ | Requirement |
| Framework | Rails 7.2 (API + web mixed mode) | Requirement; web for admin panel |
| Telegram integration | `telegram-bot` gem (webhook mode) | Requirement |
| Database | PostgreSQL 15+ via ActiveRecord | Requirement |
| Background jobs | GoodJob (ActiveRecord-backed) | No extra Redis dep; cron support built-in |
| FSM state storage | Redis via `redis-client` gem (fallback: `user_sessions` DB table) | PRD assumption |
| Testing | RSpec + FactoryBot + Shoulda Matchers | Rails standard |
| Linting | RuboCop (rubocop-rails, rubocop-rspec) | Rails standard |
| i18n | Rails I18n with `en` / `ru` locale YML files | Requirement |
| Admin | Simple scaffold controllers behind HTTP Basic Auth | PRD assumption |

### Key Gems

```ruby
# Gemfile
gem "rails", "~> 7.2"
gem "pg", "~> 1.5"
gem "puma", "~> 6.0"
gem "telegram-bot"
gem "good_job", "~> 3.0"
gem "redis-client"           # FSM state (optional; fallback to DB)
gem "bootsnap", require: false

group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "shoulda-matchers"
  gem "rubocop-rails"
  gem "rubocop-rspec"
  gem "faker"
end
```

---

## 2. High-Level Architecture

```
Telegram servers
      │  POST /telegram_webhook
      ▼
TelegramWebhooksController
      │
      ├─ command router (/start, /newgame, …)
      │        └─ CommandHandlers (concerns / service objects)
      │
      ├─ callback_query router (inline keyboard actions)
      │        └─ CallbackHandlers
      │
      └─ message router (FSM text replies)
               └─ FsmHandler (reads Redis state → delegates to GameCreator FSM)

Service objects
  GameCreator        – multi-step FSM, persists Game
  ParticipantManager – Going/Maybe/NotGoing transitions, reserve promotion
  InvitationService  – send/accept/decline invitations
  NotificationService– DM delivery via Telegram API
  TelegramMessageBuilder – formats event cards, inline keyboards

Background jobs (GoodJob)
  CheckGameThresholdsJob  – cron every 5 min
  ArchiveExpiredGamesJob  – cron every 10 min
  ReservePromotionJob     – enqueued on participant removal
  SendInvitationJob       – enqueued on organizer invite action
  NotifySubscribersJob    – enqueued on public game activation
```

---

## 3. Source Code Structure

```
app/
├── controllers/
│   ├── telegram_webhooks_controller.rb
│   └── admin/
│       ├── base_controller.rb      # HTTP Basic Auth
│       ├── users_controller.rb
│       ├── games_controller.rb
│       └── subscriptions_controller.rb
├── models/
│   ├── user.rb
│   ├── game.rb
│   ├── game_participant.rb
│   ├── location.rb
│   ├── subscription.rb
│   ├── invitation.rb
│   └── user_session.rb             # FSM fallback (if Redis unavailable)
├── services/
│   ├── game_creator.rb             # FSM steps 1–8
│   ├── participant_manager.rb
│   ├── invitation_service.rb
│   ├── notification_service.rb
│   └── telegram_message_builder.rb
├── jobs/
│   ├── check_game_thresholds_job.rb
│   ├── archive_expired_games_job.rb
│   ├── reserve_promotion_job.rb
│   ├── send_invitation_job.rb
│   └── notify_subscribers_job.rb
├── concerns/
│   ├── telegram_handler.rb         # shared response helpers (see §6.1 for full API)
│   └── fsm_state.rb                # Redis/DB-backed FSM read/write helpers
└── views/
    └── admin/                      # scaffold-style ERB views
config/
├── locales/
│   ├── en.yml
│   └── ru.yml
├── initializers/
│   ├── telegram_bot.rb
│   └── good_job.rb
└── routes.rb
db/
└── migrate/
    ├── 001_create_users.rb
    ├── 002_create_locations.rb
    ├── 003_create_games.rb
    ├── 004_create_game_participants.rb
    ├── 005_create_subscriptions.rb
    ├── 006_create_invitations.rb
    └── 007_create_user_sessions.rb
spec/
├── models/
├── services/
├── jobs/
├── controllers/
└── factories/
```

---

## 4. Data Model

### 4.1 `users`

```ruby
create_table :users do |t|
  t.bigint   :telegram_id,  null: false, index: { unique: true }
  t.string   :username
  t.string   :first_name
  t.string   :last_name
  t.integer  :role,         null: false, default: 0   # enum: participant=0, organizer=1
  t.string   :locale,       null: false, default: "en"
  t.timestamps
end
```

### 4.2 `locations`

```ruby
create_table :locations do |t|
  t.references :organizer, foreign_key: { to_table: :users }, null: false
  t.string     :name,      null: false
  t.string     :address
  t.timestamps
end
```

### 4.3 `games`

```ruby
create_table :games do |t|
  t.references :organizer,        foreign_key: { to_table: :users }, null: false
  t.references :location,         foreign_key: true, null: false
  t.integer    :sport_type,        null: false   # enum
  t.integer    :event_type,        null: false   # enum: game=0, training=1
  t.string     :title,             null: false   # auto-generated
  t.datetime   :scheduled_at,      null: false
  t.integer    :max_participants,  null: false
  t.integer    :min_participants,  null: false
  t.integer    :status,            null: false, default: 0  # enum: draft=0,active=1,cancelled=2,archived=3
  t.integer    :visibility,        null: false, default: 0  # enum: public=0,private=1
  t.bigint     :chat_id
  t.bigint     :message_id
  t.timestamps
end

add_index :games, [:organizer_id, :status]
add_index :games, [:status, :scheduled_at]
add_index :games, [:visibility, :status]
```

**Sport type enum values**: basketball=0, football=1, volleyball=2, hockey=3, tennis=4, badminton=5, other=6

### 4.4 `game_participants`

```ruby
create_table :game_participants do |t|
  t.references :game,              foreign_key: true, null: false
  t.references :user,              foreign_key: true, null: false
  t.integer    :status,            null: false, default: 0  # enum: going=0,maybe=1,not_going=2,reserve=3
  t.boolean    :invited_by_organizer, null: false, default: false
  t.boolean    :notified_reserve,     null: false, default: false
  t.timestamps
end

add_index :game_participants, [:game_id, :user_id], unique: true
add_index :game_participants, [:game_id, :status]
```

### 4.5 `subscriptions`

```ruby
create_table :subscriptions do |t|
  t.references :subscriber, foreign_key: { to_table: :users }, null: false
  t.references :organizer,  foreign_key: { to_table: :users }, null: false
  t.timestamps
end

add_index :subscriptions, [:subscriber_id, :organizer_id], unique: true
```

### 4.6 `invitations`

```ruby
create_table :invitations do |t|
  t.references :game,    foreign_key: true, null: false
  t.references :inviter, foreign_key: { to_table: :users }, null: false
  t.references :invitee, foreign_key: { to_table: :users }, null: false
  t.integer    :status,  null: false, default: 0  # enum: pending=0,accepted=1,declined=2
  t.timestamps
end

add_index :invitations, [:game_id, :invitee_id], unique: true
```

### 4.7 `user_sessions` (FSM fallback)

```ruby
create_table :user_sessions do |t|
  t.references :user,    foreign_key: true, null: false, index: { unique: true }
  t.string     :state                     # current FSM step key
  t.jsonb      :data,    default: {}      # accumulated FSM data
  t.timestamps
end
```

---

## 5. Key Model Interfaces

### `User`
```ruby
enum role: { participant: 0, organizer: 1 }
has_many :games, foreign_key: :organizer_id
has_many :game_participants
has_many :locations, foreign_key: :organizer_id
has_many :subscriptions, foreign_key: :subscriber_id
has_many :followed_organizers, through: :subscriptions, source: :organizer
has_many :invitations, foreign_key: :invitee_id

scope :organizers, -> { where(role: :organizer) }

def self.find_or_create_from_telegram(tg_user)
  find_or_create_by!(telegram_id: tg_user.id) do |u|
    u.username   = tg_user.username
    u.first_name = tg_user.first_name
    u.last_name  = tg_user.last_name
    u.locale     = tg_user.language_code&.slice(0, 2) || "en"
    u.role       = :participant
  end
end
```

### `Game`
```ruby
enum sport_type: { basketball: 0, football: 1, volleyball: 2, hockey: 3, tennis: 4, badminton: 5, other: 6 }
enum event_type: { game: 0, training: 1 }
enum status:     { draft: 0, active: 1, cancelled: 2, archived: 3 }
enum visibility: { public: 0, private: 1 }

belongs_to :organizer, class_name: "User"
belongs_to :location
has_many   :game_participants
has_many   :going_participants,   -> { going },   through: :game_participants, source: :user
has_many   :reserve_participants, -> { reserve }, through: :game_participants, source: :user
has_many   :invitations

validates :max_participants, numericality: { in: 2..100 }
validates :min_participants, numericality: { greater_than: 0 }
validate  :min_not_greater_than_max
validates :scheduled_at, comparison: { greater_than: -> { Time.current } }, on: :create
validate  :organizer_active_event_limit, on: :create

before_validation :set_title

scope :active_for_organizer, ->(organizer_id) { active.where(organizer_id: organizer_id) }
scope :public_active, -> { public.active.where("scheduled_at > ?", Time.current) }
scope :expiring_soon, -> { active.where(scheduled_at: Time.current..3.hours.from_now) }
scope :past_active,   -> { active.where("scheduled_at < ?", Time.current) }
```

### `GameParticipant`
```ruby
enum status: { going: 0, maybe: 1, not_going: 2, reserve: 3 }

belongs_to :game
belongs_to :user

scope :going,   -> { where(status: :going) }
scope :reserve, -> { where(status: :reserve) }
scope :maybe,   -> { where(status: :maybe) }
```

---

## 6. Controller Interface

### 6.1 Response Helpers (`TelegramHandler` concern)

Every command handler, callback handler, and FSM step **must** send at least one response back to Telegram. The `TelegramHandler` concern provides the following methods (all delegate to the `telegram-bot` gem's `Telegram::Bot::Client`):

```ruby
module TelegramHandler
  extend ActiveSupport::Concern

  private

  # Send a text message to the current chat.
  # Returns the sent Telegram::Bot::Types::Message (contains message_id for later edits).
  def send_message(text, reply_markup: nil, parse_mode: "HTML")
    bot.send_message(chat_id: chat.id, text: text, reply_markup: reply_markup, parse_mode: parse_mode)
  end

  # Send a text message with an InlineKeyboardMarkup to the current chat.
  def send_keyboard(i18n_key, keyboard:, **i18n_params)
    text = I18n.t(i18n_key, **i18n_params, locale: current_user.locale)
    send_message(text, reply_markup: keyboard)
  end

  # Acknowledge a callback query (dismisses the "loading" spinner on the button).
  # Optional `text` shows a brief toast notification to the user.
  def answer_callback(text: nil, show_alert: false)
    answer_callback_query(text, show_alert: show_alert)
  end

  # Edit the text and/or keyboard of an existing message (used after callback queries
  # to update event cards, FSM prompts, etc. in-place).
  def edit_message(text, message_id:, reply_markup: nil, parse_mode: "HTML")
    bot.edit_message_text(chat_id: chat.id, message_id: message_id, text: text,
                          reply_markup: reply_markup, parse_mode: parse_mode)
  end

  # Send a DM (private message) to a specific user by their telegram_id.
  def send_dm(telegram_id, text, reply_markup: nil)
    bot.send_message(chat_id: telegram_id, text: text, reply_markup: reply_markup)
  end
end
```

### 6.2 `TelegramWebhooksController`

All handler methods below must use the `TelegramHandler` helpers to respond. The controller never returns silently — if an unexpected error occurs, it catches the exception and calls `send_message` with the `bot.generic_error` i18n key.

```ruby
class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include TelegramHandler
  include FsmState

  rescue_from StandardError, with: :handle_unexpected_error

  # Commands — each handler MUST call send_message / send_keyboard to respond
  def start!(*)     ; Commands::StartHandler.call(self, current_user) ; end
  def newgame!(*)   ; Commands::NewGameHandler.call(self, current_user) ; end
  def mygames!(*)   ; Commands::MyGamesHandler.call(self, current_user) ; end
  def archive!(*)   ; Commands::ArchiveHandler.call(self, current_user) ; end
  def publicgames!(*); Commands::PublicGamesHandler.call(self, current_user) ; end
  def settings!(*)  ; Commands::SettingsHandler.call(self, current_user) ; end
  def help!(*)      ; Commands::HelpHandler.call(self, current_user) ; end

  # Callback queries — handler MUST call answer_callback + optionally edit_message
  def callback_query(data)
    CallbackRouter.dispatch(self, current_user, data)
  end

  # Plain text messages → FSM — handler MUST respond with next step prompt or error
  def message(message)
    FsmHandler.handle(self, current_user, message.text)
  end

  # Unrecognized commands → friendly fallback
  def action_missing(action, *_args)
    send_message(I18n.t("bot.unknown_command", locale: current_user&.locale || "en"))
  end

  private

  def current_user
    @current_user ||= User.find_or_create_from_telegram(from)
  end

  def handle_unexpected_error(exception)
    Rails.logger.error("Telegram handler error: #{exception.message}")
    send_message(I18n.t("bot.generic_error", locale: current_user&.locale || "en"))
  end
end
```

**Callback data format**: `"<action>:<param1>:<param2>"`, e.g. `"vote:going:42"`, `"fsm:sport:basketball"`.

### Admin Controllers (`/admin/*`)

Protected by `Admin::BaseController` using `http_basic_authenticate_with`.
Standard Rails resource controllers for `users`, `games`, `subscriptions` with index/show/update actions.

---

## 7. Service Object Interfaces

### `GameCreator` (multi-step FSM)

FSM steps stored in Redis key `"fsm:#{user_id}"` as JSON `{ step: "sport_type", data: {} }`.

```
Steps (in order):
  sport_type → event_type → datetime → location → max_participants →
  min_participants → visibility → confirmation
```

```ruby
class GameCreator
  STEPS = %w[sport_type event_type datetime location max_participants
             min_participants visibility confirmation].freeze

  # Responds with sport_type inline keyboard
  def self.start(user, controller)
    write_state(user.id, step: "sport_type", data: {})
    controller.send_keyboard("bot.select_sport_type",
                             keyboard: TelegramMessageBuilder.sport_type_keyboard)
  end

  # Responds with next step keyboard/prompt, or error message on validation failure.
  # On confirmation step: responds with success message + event card.
  def self.handle_callback(user, controller, step, value)
    state = read_state(user.id)
    # validate + advance step
    # respond with next step prompt via controller.send_keyboard or controller.send_message
    # on confirmation: persist Game, clear state, notify subscribers, respond with event card
  end

  # Responds with next step prompt on valid input, or validation error message + re-prompt.
  def self.handle_text(user, controller, text)
    state = read_state(user.id)
    # handle datetime / location_name / max / min text inputs
    # respond with next step prompt or validation error via controller.send_message
  end

  # Responds with success confirmation + event card.
  def self.finish(user, controller, data)
    game = nil
    Game.transaction do
      location = Location.find_or_create_by!(organizer: user, name: data[:location_name])
      game = Game.create!(data.merge(organizer: user, location: location, status: :active))
      NotifySubscribersJob.perform_later(game.id) if game.public?
    end
    clear_state(user.id)
    # Respond with event card to the organizer
    card = TelegramMessageBuilder.event_card(game)
    controller.send_message(card[:text], reply_markup: card[:reply_markup])
  end
end
```

### `ParticipantManager`

```ruby
class ParticipantManager
  # Returns a result hash that the caller uses to respond:
  #   { status: :voted, participant_status: :going | :maybe | :not_going | :reserve }
  # The callback handler must then:
  #   1. answer_callback with a toast (e.g., "Vote recorded" / "Added to reserve")
  #   2. edit_message to update the event card with new participant counts
  def self.vote(game:, user:, vote:)
    # :going, :maybe, :not_going
    # transaction: upsert game_participant, check capacity, promote reserve if going→not_going
    ActiveRecord::Base.transaction do
      # ...
      ReservePromotionJob.perform_later(game.id) if spot_freed?
    end
  end

  # After removal:
  #   1. Sends DM to removed user: "The organizer removed you from [event]."
  #   2. Responds to organizer with updated participant list
  #   3. Triggers reserve promotion
  def self.remove(game:, user:, remover:)
    # organizer removes participant; send notification DM via NotificationService
    # triggers reserve promotion
  end
end
```

### `TelegramMessageBuilder`

```ruby
class TelegramMessageBuilder
  def self.event_card(game)
    # Returns { text: "...", reply_markup: inline_keyboard }
  end

  def self.vote_keyboard(game)
    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [[
        { text: "✅ Going (#{going_count})",   callback_data: "vote:going:#{game.id}" },
        { text: "🤔 Maybe (#{maybe_count})",   callback_data: "vote:maybe:#{game.id}" },
        { text: "❌ Not going",                callback_data: "vote:not_going:#{game.id}" }
      ]]
    )
  end

  def self.sport_type_keyboard
    # 2-column keyboard of sport types
  end

  def self.location_keyboard(locations)
    # Existing locations + "New location" button
  end
end
```

---

## 8. Background Job Interfaces

### `CheckGameThresholdsJob`

```ruby
class CheckGameThresholdsJob < ApplicationJob
  # GoodJob cron: every 5 minutes
  def perform
    Game.expiring_soon.find_each do |game|
      going_count = game.game_participants.going.count
      next if going_count >= game.min_participants

      game.update!(status: :cancelled)
      NotificationService.notify_cancellation(game)
    end
  end
end
```

### `ArchiveExpiredGamesJob`

```ruby
class ArchiveExpiredGamesJob < ApplicationJob
  # GoodJob cron: every 10 minutes
  def perform
    Game.past_active.update_all(status: :archived)
  end
end
```

### `ReservePromotionJob`

```ruby
class ReservePromotionJob < ApplicationJob
  def perform(game_id)
    game = Game.find(game_id)
    return unless game.active?
    return unless game.game_participants.going.count < game.max_participants

    reserve = game.game_participants.reserve.order(:created_at).first
    return unless reserve && !reserve.notified_reserve?

    reserve.update!(notified_reserve: true)
    NotificationService.notify_reserve_promotion(reserve.user, game)
  end
end
```

---

## 9. Routes Configuration

```ruby
Rails.application.routes.draw do
  telegram_webhook :telegram_webhooks    # POST /telegram_webhook

  namespace :admin do
    resources :users,         only: [:index, :show, :update]
    resources :games,         only: [:index, :show, :update]
    resources :subscriptions, only: [:index, :destroy]
    root to: "games#index"
  end
end
```

---

## 10. GoodJob Cron Configuration

```ruby
# config/initializers/good_job.rb
GoodJob.configure do |config|
  config.execution_mode = :external
  config.cron = {
    check_game_thresholds: {
      cron:  "*/5 * * * *",
      class: "CheckGameThresholdsJob"
    },
    archive_expired_games: {
      cron:  "*/10 * * * *",
      class: "ArchiveExpiredGamesJob"
    }
  }
end
```

---

## 11. Environment Variables

| Variable | Purpose |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Bot API token |
| `WEBHOOK_URL` | Public HTTPS URL for webhook registration |
| `DATABASE_URL` | PostgreSQL connection string |
| `REDIS_URL` | Redis connection (FSM state; optional if DB fallback used) |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | HTTP Basic Auth for `/admin` |

---

## 12. i18n Structure

```yaml
# config/locales/en.yml
en:
  bot:
    welcome: "Welcome, %{name}! You are now registered."
    not_authorized: "You must be registered first. Use /start."
    generic_error: "Something went wrong. Please try again later."
    unknown_command: "Unknown command. Use /help to see available commands."
    select_sport_type: "Choose a sport type:"
    select_event_type: "Is this a game or a training session?"
    enter_datetime: "Enter date and time (DD.MM.YYYY HH:MM):"
    vote_recorded: "Vote recorded!"
    added_to_reserve: "Game is full. You've been added to the reserve list."
    fsm_cancelled: "Game creation cancelled."
    game_created: "Game created successfully!"
    no_active_games: "You have no active games."
    no_archived_games: "You have no archived games."
    no_public_games: "No public games available right now."
    # ... all bot prompts
  game:
    title_format: "%{sport} (%{event_type})"
    event_types:
      game: "Game"
      training: "Training"
    sport_types:
      basketball: "Basketball"
      # ...
  notifications:
    cancellation: "❌ Event \"%{title}\" on %{date} has been cancelled."
    reserve_promotion: "A spot opened in \"%{title}\". Join? [Yes] [No]"
    invitation: "%{organizer} invited you to \"%{title}\". [Accept] [Decline]"
```

---

## 13. Delivery Phases

### Phase 1 — Foundation (DB + bot skeleton)
- Gemfile, Rails app init, `.gitignore`
- All migrations (users, locations, games, game_participants, subscriptions, invitations, user_sessions)
- `TelegramWebhooksController` with `/start` (user upsert, locale detection)
- `User`, `Location`, `Game`, `GameParticipant`, `Subscription`, `Invitation`, `UserSession` models with validations and associations
- Routes (`telegram_webhook`, admin namespace)
- RSpec + FactoryBot setup; model specs

### Phase 2 — Game Creation FSM
- `GameCreator` service with all 8 FSM steps
- Redis FSM state helpers (`FsmState` concern)
- `TelegramMessageBuilder` keyboard builders
- `/newgame` command handler (concurrent-event-limit check)
- Inline keyboard callback routing for FSM
- Service specs + controller integration spec for game creation flow

### Phase 3 — Participation & Voting
- `ParticipantManager` service (Going/Maybe/NotGoing transitions, reserve logic)
- `vote_keyboard` inline keyboard and callback handler
- `ReservePromotionJob` and `SendInvitationJob`
- `InvitationService` (send, accept, decline)
- `/mygames` command: list + manage participants + remove + self-vote
- Participant removal DM notification
- Service and job specs

### Phase 4 — Discovery & Subscriptions
- `/publicgames` with inline-keyboard pagination and filters (sport, location, organizer)
- `/settings` subscription management
- `NotifySubscribersJob` triggered on game activation
- Subscription model CRUD via inline keyboards
- Feature specs for public game listing

### Phase 5 — Archive, Relaunch & Background Jobs
- `/archive` command with Relaunch flow (abbreviated FSM: sport/event pre-filled, ask date)
- `CheckGameThresholdsJob` (cron, auto-cancel)
- `ArchiveExpiredGamesJob` (cron)
- `NotificationService` (cancellation broadcasts)
- GoodJob cron configuration
- Job specs with time-travel helpers

### Phase 6 — Admin Panel & i18n
- Admin controllers (users, games, subscriptions) with HTTP Basic Auth
- Scaffold-style ERB views
- `en.yml` and `ru.yml` locale files covering all bot messages
- RuboCop configuration and full lint pass
- Final integration and system specs

---

## 14. Verification Approach

```bash
# Lint
bundle exec rubocop

# Type checks (optional; Sorbet/Steep not required for v1)

# Tests
bundle exec rspec

# Database
bundle exec rails db:migrate
bundle exec rails db:migrate STATUS   # ensure no pending migrations

# GoodJob worker (dev)
bundle exec good_job start
```

All specs must pass before a phase is considered complete. CI (GitHub Actions or similar) should run `rubocop` and `rspec` on every push.
