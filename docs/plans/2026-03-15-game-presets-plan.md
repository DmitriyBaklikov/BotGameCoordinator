# Game Presets Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow organizers to save game configurations as reusable presets (max 5) and create games from them by only entering date/time.

**Architecture:** Two new DB tables (`game_presets`, `game_preset_invitees`), a `PresetService` for CRUD, a `PresetsHandler` command for management, and extensions to `GameCreator`/`NewGameHandler`/`CallbackRouter`/`FsmHandler` for the preset-based game creation flow and post-creation save prompt.

**Tech Stack:** Rails 7.2, PostgreSQL, telegram-bot gem, RSpec + FactoryBot

---

### Task 1: Database migrations

**Files:**
- Create: `db/migrate/XXXXXX_create_game_presets.rb`
- Create: `db/migrate/XXXXXX_create_game_preset_invitees.rb`

**Step 1: Generate the game_presets migration**

Run:
```bash
bin/rails generate migration CreateGamePresets organizer_id:bigint:index name:string sport_type:integer event_type:integer location_id:bigint max_participants:integer min_participants:integer visibility:integer --no-test-framework
```

Then edit the generated migration to match:

```ruby
class CreateGamePresets < ActiveRecord::Migration[7.2]
  def change
    create_table :game_presets do |t|
      t.bigint :organizer_id, null: false
      t.string :name, null: false
      t.integer :sport_type, null: false
      t.integer :event_type, null: false
      t.bigint :location_id, null: false
      t.integer :max_participants, null: false
      t.integer :min_participants, null: false
      t.integer :visibility, default: 0, null: false
      t.timestamps
    end

    add_index :game_presets, :organizer_id
    add_foreign_key :game_presets, :users, column: :organizer_id
    add_foreign_key :game_presets, :locations
  end
end
```

**Step 2: Generate the game_preset_invitees migration**

Run:
```bash
bin/rails generate migration CreateGamePresetInvitees game_preset_id:bigint user_id:bigint username:string --no-test-framework
```

Then edit:

```ruby
class CreateGamePresetInvitees < ActiveRecord::Migration[7.2]
  def change
    create_table :game_preset_invitees do |t|
      t.bigint :game_preset_id, null: false
      t.bigint :user_id
      t.string :username
      t.timestamps
    end

    add_index :game_preset_invitees, :game_preset_id
    add_index :game_preset_invitees, [:game_preset_id, :user_id], unique: true, where: "user_id IS NOT NULL", name: "idx_preset_invitees_unique_user"
    add_foreign_key :game_preset_invitees, :game_presets
    add_foreign_key :game_preset_invitees, :users
  end
end
```

**Step 3: Run migrations**

Run: `bin/rails db:migrate`
Expected: Both tables created, `db/schema.rb` updated.

**Step 4: Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "feat: add game_presets and game_preset_invitees tables"
```

---

### Task 2: GamePreset and GamePresetInvitee models

**Files:**
- Create: `app/models/game_preset.rb`
- Create: `app/models/game_preset_invitee.rb`
- Modify: `app/models/user.rb` — add `has_many :game_presets`
- Create: `spec/factories/game_presets.rb`
- Create: `spec/factories/game_preset_invitees.rb`
- Create: `spec/models/game_preset_spec.rb`
- Create: `spec/models/game_preset_invitee_spec.rb`

**Step 1: Write model tests**

```ruby
# spec/models/game_preset_spec.rb
require "rails_helper"

RSpec.describe GamePreset do
  describe "associations" do
    it { is_expected.to belong_to(:organizer).class_name("User") }
    it { is_expected.to belong_to(:location) }
    it { is_expected.to have_many(:game_preset_invitees).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:sport_type) }
    it { is_expected.to validate_presence_of(:event_type) }
    it { is_expected.to validate_presence_of(:max_participants) }
    it { is_expected.to validate_presence_of(:min_participants) }
  end

  describe "preset limit" do
    let(:organizer) { create(:user, :organizer) }
    let(:location) { create(:location, organizer: organizer) }

    it "allows up to 5 presets" do
      5.times { create(:game_preset, organizer: organizer, location: location) }
      sixth = build(:game_preset, organizer: organizer, location: location)
      expect(sixth).not_to be_valid
      expect(sixth.errors[:base]).to include("Preset limit reached (maximum 5)")
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:sport_type).with_values(basketball: 0, football: 1, volleyball: 2, hockey: 3, tennis: 4, badminton: 5, other: 6) }
    it { is_expected.to define_enum_for(:event_type).with_values(game: 0, training: 1) }
    it { is_expected.to define_enum_for(:visibility).with_values(public_game: 0, private_game: 1) }
  end
end
```

```ruby
# spec/models/game_preset_invitee_spec.rb
require "rails_helper"

RSpec.describe GamePresetInvitee do
  describe "associations" do
    it { is_expected.to belong_to(:game_preset) }
    it { is_expected.to belong_to(:user).optional }
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/game_preset_spec.rb spec/models/game_preset_invitee_spec.rb`
Expected: FAIL — models don't exist yet.

**Step 3: Create factories**

```ruby
# spec/factories/game_presets.rb
FactoryBot.define do
  factory :game_preset do
    association :organizer, factory: [:user, :organizer]
    association :location
    name { "Basketball (Game) / Test Location" }
    sport_type { :basketball }
    event_type { :game }
    max_participants { 10 }
    min_participants { 4 }
    visibility { :public_game }
  end
end
```

```ruby
# spec/factories/game_preset_invitees.rb
FactoryBot.define do
  factory :game_preset_invitee do
    association :game_preset
    association :user
    username { "testuser" }

    trait :unknown_user do
      user { nil }
      username { "unknown_user" }
    end
  end
end
```

**Step 4: Create models**

```ruby
# app/models/game_preset.rb
class GamePreset < ApplicationRecord
  MAX_PRESETS_PER_ORGANIZER = 5

  enum sport_type: { basketball: 0, football: 1, volleyball: 2, hockey: 3, tennis: 4, badminton: 5, other: 6 }
  enum event_type: { game: 0, training: 1 }
  enum visibility: { public_game: 0, private_game: 1 }

  belongs_to :organizer, class_name: "User"
  belongs_to :location

  has_many :game_preset_invitees, dependent: :destroy

  validates :name, presence: true
  validates :sport_type, presence: true
  validates :event_type, presence: true
  validates :max_participants, presence: true, numericality: { only_integer: true, in: 2..100 }
  validates :min_participants, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :visibility, presence: true

  validate :preset_limit, on: :create

  private

  def preset_limit
    return if organizer_id.blank?
    return if GamePreset.where(organizer_id: organizer_id).count < MAX_PRESETS_PER_ORGANIZER

    errors.add(:base, "Preset limit reached (maximum #{MAX_PRESETS_PER_ORGANIZER})")
  end
end
```

```ruby
# app/models/game_preset_invitee.rb
class GamePresetInvitee < ApplicationRecord
  belongs_to :game_preset
  belongs_to :user, optional: true
end
```

**Step 5: Add association to User model**

In `app/models/user.rb`, add after existing `has_many` lines:

```ruby
has_many :game_presets, foreign_key: :organizer_id, dependent: :destroy
```

**Step 6: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/game_preset_spec.rb spec/models/game_preset_invitee_spec.rb`
Expected: All PASS.

**Step 7: Commit**

```bash
git add app/models/game_preset.rb app/models/game_preset_invitee.rb app/models/user.rb spec/
git commit -m "feat: add GamePreset and GamePresetInvitee models with validations"
```

---

### Task 3: PresetService

**Files:**
- Create: `app/services/preset_service.rb`
- Create: `spec/services/preset_service_spec.rb`

**Step 1: Write tests**

```ruby
# spec/services/preset_service_spec.rb
require "rails_helper"

RSpec.describe PresetService do
  let(:organizer) { create(:user, :organizer) }
  let(:location) { create(:location, organizer: organizer) }
  let(:invitee1) { create(:user, username: "player1") }
  let(:invitee2) { create(:user, username: "player2") }

  describe ".create_from_game_data" do
    let(:game_data) do
      {
        sport_type: "basketball",
        event_type: "game",
        location_id: location.id,
        max_participants: 10,
        min_participants: 4,
        visibility: "public_game"
      }
    end

    it "creates a preset with auto-generated name" do
      preset = PresetService.create_from_game_data(organizer: organizer, game_data: game_data, locale: :en)
      expect(preset).to be_persisted
      expect(preset.name).to include("Basketball")
      expect(preset.sport_type).to eq("basketball")
      expect(preset.location_id).to eq(location.id)
    end

    it "creates a preset with invitees" do
      invitees = [{ user_id: invitee1.id, username: invitee1.username }, { username: "unknown_guy" }]
      preset = PresetService.create_from_game_data(organizer: organizer, game_data: game_data, invitees: invitees, locale: :en)
      expect(preset.game_preset_invitees.count).to eq(2)
      expect(preset.game_preset_invitees.find_by(user_id: invitee1.id)).to be_present
      expect(preset.game_preset_invitees.find_by(username: "unknown_guy")).to be_present
    end
  end

  describe ".auto_name" do
    it "generates name from sport, event type, and location" do
      name = PresetService.auto_name(
        sport_type: "basketball",
        event_type: "game",
        location_name: "Central Court",
        locale: :en
      )
      expect(name).to eq("🏀 Basketball (🎾 Game) / Central Court")
    end
  end

  describe ".build_game_data" do
    it "extracts game creation data from preset" do
      preset = create(:game_preset, organizer: organizer, location: location)
      data = PresetService.build_game_data(preset)
      expect(data[:sport_type]).to eq(preset.sport_type)
      expect(data[:event_type]).to eq(preset.event_type)
      expect(data[:location_id]).to eq(preset.location_id)
      expect(data[:max_participants]).to eq(preset.max_participants)
      expect(data[:min_participants]).to eq(preset.min_participants)
      expect(data[:visibility]).to eq(preset.visibility)
    end
  end

  describe ".delete" do
    it "destroys the preset and its invitees" do
      preset = create(:game_preset, organizer: organizer, location: location)
      create(:game_preset_invitee, game_preset: preset, user: invitee1, username: invitee1.username)

      expect { PresetService.delete(preset) }.to change(GamePreset, :count).by(-1)
        .and change(GamePresetInvitee, :count).by(-1)
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/services/preset_service_spec.rb`
Expected: FAIL — service doesn't exist.

**Step 3: Implement PresetService**

```ruby
# app/services/preset_service.rb
class PresetService
  def self.create_from_game_data(organizer:, game_data:, invitees: [], locale: :en)
    location = Location.find(game_data[:location_id])

    preset = GamePreset.create!(
      organizer:        organizer,
      name:             auto_name(
        sport_type: game_data[:sport_type],
        event_type: game_data[:event_type],
        location_name: location.name,
        locale: locale
      ),
      sport_type:       game_data[:sport_type],
      event_type:       game_data[:event_type],
      location_id:      game_data[:location_id],
      max_participants: game_data[:max_participants].to_i,
      min_participants: game_data[:min_participants].to_i,
      visibility:       game_data[:visibility] || "public_game"
    )

    invitees.each do |inv|
      preset.game_preset_invitees.create!(
        user_id:  inv[:user_id],
        username: inv[:username]
      )
    end

    preset
  end

  def self.replace(old_preset:, organizer:, game_data:, invitees: [], locale: :en)
    old_preset.destroy!
    create_from_game_data(organizer: organizer, game_data: game_data, invitees: invitees, locale: locale)
  end

  def self.update_field(preset, field, value)
    preset.update!(field => value)
  end

  def self.delete(preset)
    preset.destroy!
  end

  def self.build_game_data(preset)
    {
      sport_type:       preset.sport_type,
      event_type:       preset.event_type,
      location_id:      preset.location_id,
      max_participants: preset.max_participants,
      min_participants: preset.min_participants,
      visibility:       preset.visibility
    }
  end

  def self.auto_name(sport_type:, event_type:, location_name:, locale: :en)
    sport = I18n.t("game.sport_types.#{sport_type}", locale: locale)
    evt   = I18n.t("game.event_types.#{event_type}", locale: locale)
    "#{sport} (#{evt}) / #{location_name}"
  end

  def self.preset_summary(preset, locale: :en)
    sport = I18n.t("game.sport_types.#{preset.sport_type}", locale: locale)
    evt   = I18n.t("game.event_types.#{preset.event_type}", locale: locale)
    vis   = I18n.t("game.visibility.#{preset.visibility.sub("_game", "")}", locale: locale)
    loc   = preset.location.name

    invitee_names = preset.game_preset_invitees.map { |i| "@#{i.username}" }
    invitee_text  = invitee_names.any? ? invitee_names.join(", ") : I18n.t("bot.presets.no_invitees", locale: locale)

    <<~TEXT
      🏟 #{sport} (#{evt})
      📍 #{loc}
      👥 #{preset.max_participants} max / #{preset.min_participants} min
      👁 #{vis}
      📨 #{invitee_text}
    TEXT
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/services/preset_service_spec.rb`
Expected: All PASS.

**Step 5: Commit**

```bash
git add app/services/preset_service.rb spec/services/preset_service_spec.rb
git commit -m "feat: add PresetService for game preset CRUD operations"
```

---

### Task 4: I18n keys

**Files:**
- Modify: `config/locales/en.yml`
- Modify: `config/locales/ru.yml`

**Step 1: Add English locale keys**

Add under `bot:` section in `config/locales/en.yml`, after the `settings:` block:

```yaml
    # Presets
    presets:
      choose_prompt: "Create a new game or use a preset?"
      new_game_button: "🆕 New game"
      summary_title: "📋 Preset summary:"
      change_anything: "Want to change anything?"
      no_change: "✅ No, just set date/time"
      change_something: "✏️ Change something"
      select_field: "What would you like to change?"
      field_sport_type: "🏟 Sport type"
      field_event_type: "🎾 Event type"
      field_location: "📍 Location"
      field_max_participants: "👥 Max participants"
      field_min_participants: "👥 Min participants"
      field_visibility: "👁 Visibility"
      field_invitees: "📨 Invitees"
      confirm_invitees: "These players will be invited:\n%{list}\nProceed?"
      no_invitees: "None"
      save_prompt: "Save this game as a preset?"
      preset_saved: "Preset saved: %{name}"
      preset_limit_replace: "You have 5 presets. Which one would you like to replace?"
      preset_replaced: "Preset replaced."
      preset_deleted: "Preset deleted."
      delete_confirm: "Delete preset \"%{name}\"? This cannot be undone."
      no_presets: "You have no presets yet."
      preset_list_title: "📋 Your presets:"
      preset_updated: "Preset updated."
      back: "⬅️ Back"
      done: "✅ Done"
      manage_presets: "📋 Manage presets"
      edit: "✏️ Edit"
      delete: "🗑 Delete"
      add_invitee_prompt: "Enter @username to add to this preset:"
      invitee_added: "Added @%{username} to preset."
      remove_invitee: "Remove an invitee"
      invitee_removed: "Removed @%{username} from preset."
      location_deleted_warning: "The location in this preset no longer exists. Please select a new one."
```

Add to `help:` section:

```yaml
      presets: "/presets — Manage game presets"
```

**Step 2: Add Russian locale keys**

Add under `bot:` section in `config/locales/ru.yml`:

```yaml
    presets:
      choose_prompt: "Создать новую игру или использовать шаблон?"
      new_game_button: "🆕 Новая игра"
      summary_title: "📋 Шаблон:"
      change_anything: "Хотите что-то изменить?"
      no_change: "✅ Нет, только выбрать дату и время"
      change_something: "✏️ Изменить"
      select_field: "Что хотите изменить?"
      field_sport_type: "🏟 Вид спорта"
      field_event_type: "🎾 Тип события"
      field_location: "📍 Место"
      field_max_participants: "👥 Макс. участников"
      field_min_participants: "👥 Мин. участников"
      field_visibility: "👁 Видимость"
      field_invitees: "📨 Приглашённые"
      confirm_invitees: "Эти игроки будут приглашены:\n%{list}\nПродолжить?"
      no_invitees: "Нет"
      save_prompt: "Сохранить эту игру как шаблон?"
      preset_saved: "Шаблон сохранён: %{name}"
      preset_limit_replace: "У вас 5 шаблонов. Какой заменить?"
      preset_replaced: "Шаблон заменён."
      preset_deleted: "Шаблон удалён."
      delete_confirm: "Удалить шаблон \"%{name}\"? Это действие нельзя отменить."
      no_presets: "У вас пока нет шаблонов."
      preset_list_title: "📋 Ваши шаблоны:"
      preset_updated: "Шаблон обновлён."
      back: "⬅️ Назад"
      done: "✅ Готово"
      manage_presets: "📋 Управление шаблонами"
      edit: "✏️ Редактировать"
      delete: "🗑 Удалить"
      add_invitee_prompt: "Введите @username для добавления в шаблон:"
      invitee_added: "@%{username} добавлен(а) в шаблон."
      remove_invitee: "Удалить приглашённого"
      invitee_removed: "@%{username} удалён(а) из шаблона."
      location_deleted_warning: "Место в этом шаблоне больше не существует. Выберите новое."
```

Add to `help:` section:

```yaml
      presets: "/presets — Управление шаблонами игр"
```

**Step 3: Commit**

```bash
git add config/locales/
git commit -m "feat: add i18n keys for game presets (en + ru)"
```

---

### Task 5: TelegramMessageBuilder — preset keyboards

**Files:**
- Modify: `app/services/telegram_message_builder.rb`

**Step 1: Add preset keyboard builder methods**

Add these methods to `TelegramMessageBuilder` class:

```ruby
def self.choose_preset_keyboard(presets, locale: :en)
  locale = locale.to_sym
  buttons = presets.map do |preset|
    [Telegram::Bot::Types::InlineKeyboardButton.new(
      text:          "📋 #{preset.name}",
      callback_data: "preset:select:#{preset.id}"
    )]
  end

  buttons << [Telegram::Bot::Types::InlineKeyboardButton.new(
    text:          I18n.t("bot.presets.new_game_button", locale: locale),
    callback_data: "preset:new_game"
  )]

  Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
end

def self.preset_change_keyboard(locale: :en)
  locale = locale.to_sym
  Telegram::Bot::Types::InlineKeyboardMarkup.new(
    inline_keyboard: [
      [
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          I18n.t("bot.presets.no_change", locale: locale),
          callback_data: "preset:no_change"
        )
      ],
      [
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          I18n.t("bot.presets.change_something", locale: locale),
          callback_data: "preset:change"
        )
      ]
    ]
  )
end

def self.preset_edit_menu_keyboard(preset_id, locale: :en)
  locale = locale.to_sym
  fields = %w[sport_type event_type location max_participants min_participants visibility invitees]
  buttons = fields.map do |field|
    [Telegram::Bot::Types::InlineKeyboardButton.new(
      text:          I18n.t("bot.presets.field_#{field}", locale: locale),
      callback_data: "preset:edit_field:#{preset_id}:#{field}"
    )]
  end

  buttons << [Telegram::Bot::Types::InlineKeyboardButton.new(
    text:          I18n.t("bot.presets.done", locale: locale),
    callback_data: "preset:edit_done:#{preset_id}"
  )]

  Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
end

def self.preset_list_keyboard(presets, locale: :en)
  locale = locale.to_sym
  buttons = presets.map do |preset|
    [Telegram::Bot::Types::InlineKeyboardButton.new(
      text:          "📋 #{preset.name}",
      callback_data: "preset:view:#{preset.id}"
    )]
  end

  Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
end

def self.preset_actions_keyboard(preset_id, locale: :en)
  locale = locale.to_sym
  Telegram::Bot::Types::InlineKeyboardMarkup.new(
    inline_keyboard: [
      [
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          I18n.t("bot.presets.edit", locale: locale),
          callback_data: "preset:manage_edit:#{preset_id}"
        ),
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          I18n.t("bot.presets.delete", locale: locale),
          callback_data: "preset:delete_confirm:#{preset_id}"
        )
      ],
      [
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          I18n.t("bot.presets.back", locale: locale),
          callback_data: "preset:manage_list"
        )
      ]
    ]
  )
end

def self.preset_delete_confirm_keyboard(preset_id, locale: :en)
  locale = locale.to_sym
  Telegram::Bot::Types::InlineKeyboardMarkup.new(
    inline_keyboard: [
      [
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          "✅ #{I18n.t("bot.yes", locale: locale)}",
          callback_data: "preset:delete_yes:#{preset_id}"
        ),
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          "❌ #{I18n.t("bot.no", locale: locale)}",
          callback_data: "preset:delete_no:#{preset_id}"
        )
      ]
    ]
  )
end

def self.save_preset_keyboard(locale: :en)
  locale = locale.to_sym
  Telegram::Bot::Types::InlineKeyboardMarkup.new(
    inline_keyboard: [
      [
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          "✅ #{I18n.t("bot.yes", locale: locale)}",
          callback_data: "preset:save_yes"
        ),
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          "❌ #{I18n.t("bot.no", locale: locale)}",
          callback_data: "preset:save_no"
        )
      ]
    ]
  )
end

def self.preset_replace_keyboard(presets, locale: :en)
  locale = locale.to_sym
  buttons = presets.map do |preset|
    [Telegram::Bot::Types::InlineKeyboardButton.new(
      text:          "📋 #{preset.name}",
      callback_data: "preset:replace:#{preset.id}"
    )]
  end

  Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
end

def self.preset_confirm_invitees_keyboard(locale: :en)
  locale = locale.to_sym
  Telegram::Bot::Types::InlineKeyboardMarkup.new(
    inline_keyboard: [
      [
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          "✅ #{I18n.t("bot.yes", locale: locale)}",
          callback_data: "preset:invitees_yes"
        ),
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          "❌ #{I18n.t("bot.no", locale: locale)}",
          callback_data: "preset:invitees_no"
        )
      ]
    ]
  )
end

def self.preset_invitees_edit_keyboard(preset, locale: :en)
  locale = locale.to_sym
  buttons = preset.game_preset_invitees.map do |inv|
    [Telegram::Bot::Types::InlineKeyboardButton.new(
      text:          "❌ @#{inv.username}",
      callback_data: "preset:remove_invitee:#{preset.id}:#{inv.id}"
    )]
  end

  buttons << [Telegram::Bot::Types::InlineKeyboardButton.new(
    text:          "➕ #{I18n.t("bot.manage.invite", locale: locale)}",
    callback_data: "preset:add_invitee:#{preset.id}"
  )]

  buttons << [Telegram::Bot::Types::InlineKeyboardButton.new(
    text:          I18n.t("bot.presets.done", locale: locale),
    callback_data: "preset:edit_done:#{preset.id}"
  )]

  Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
end
```

**Step 2: Commit**

```bash
git add app/services/telegram_message_builder.rb
git commit -m "feat: add preset keyboard builders to TelegramMessageBuilder"
```

---

### Task 6: PresetsHandler command + /presets registration

**Files:**
- Create: `app/commands/commands/presets_handler.rb`
- Modify: `app/controllers/telegram_bot_controller.rb` — add `presets!` method
- Modify: `app/commands/commands/settings_handler.rb` — add "Manage presets" button

**Step 1: Create PresetsHandler**

```ruby
# app/commands/commands/presets_handler.rb
module Commands
  class PresetsHandler
    def self.call(controller, user)
      locale = user.locale.to_sym

      unless user.organizer?
        controller.send_message(controller.from.id, I18n.t("bot.not_authorized", locale: locale))
        return
      end

      presets = user.game_presets.includes(:location)

      if presets.empty?
        controller.send_message(
          user.telegram_id,
          I18n.t("bot.presets.no_presets", locale: locale)
        )
        return
      end

      controller.send_message(
        user.telegram_id,
        I18n.t("bot.presets.preset_list_title", locale: locale),
        reply_markup: TelegramMessageBuilder.preset_list_keyboard(presets, locale: locale)
      )
    end

    def self.show_preset(controller, user, preset_id)
      locale = user.locale.to_sym
      preset = user.game_presets.includes(:location, :game_preset_invitees).find_by(id: preset_id)
      return unless preset

      summary = PresetService.preset_summary(preset, locale: locale)
      controller.send_message(
        user.telegram_id,
        "#{I18n.t("bot.presets.summary_title", locale: locale)}\n\n#{summary}",
        reply_markup: TelegramMessageBuilder.preset_actions_keyboard(preset.id, locale: locale)
      )
    end
  end
end
```

**Step 2: Register /presets command**

Add to `app/controllers/telegram_bot_controller.rb` after the `settings!` method:

```ruby
def presets!(*)
  ::Commands::PresetsHandler.call(self, current_user)
end
```

**Step 3: Add "Manage presets" button to Settings**

In `app/commands/commands/settings_handler.rb`, add a new row to the `settings_keyboard` method — after the timezone row, add (only for organizers):

```ruby
# Inside settings_keyboard method, before the final closing of inline_keyboard array
rows = [
  # ... existing rows ...
]

if user.organizer?
  rows << [
    Telegram::Bot::Types::InlineKeyboardButton.new(
      text:          I18n.t("bot.presets.manage_presets", locale: locale),
      callback_data: "settings:presets"
    )
  ]
end
```

**Step 4: Add the settings:presets callback**

In `app/commands/callback_router.rb`, inside `handle_settings`, add a new `when` case:

```ruby
when "presets"
  Commands::PresetsHandler.call(@controller, @user)
  answer_callback
```

**Step 5: Commit**

```bash
git add app/commands/commands/presets_handler.rb app/controllers/telegram_bot_controller.rb app/commands/commands/settings_handler.rb app/commands/callback_router.rb
git commit -m "feat: add /presets command and settings entry point"
```

---

### Task 7: CallbackRouter — preset callbacks

**Files:**
- Modify: `app/commands/callback_router.rb` — add `"preset"` handler to HANDLERS and implement `handle_preset`

**Step 1: Register preset handler in HANDLERS hash**

Add to the `HANDLERS` hash in `callback_router.rb`:

```ruby
"preset" => :handle_preset,
```

**Step 2: Implement handle_preset method**

Add this method to the `CallbackRouter` class:

```ruby
def handle_preset
  action = @parts[1]

  case action
  when "select"
    handle_preset_select
  when "new_game"
    Commands::NewGameHandler.start_fresh(@controller, @user)
    answer_callback
  when "no_change"
    handle_preset_no_change
  when "change"
    handle_preset_change
  when "edit_field"
    handle_preset_edit_field
  when "edit_done"
    handle_preset_edit_done
  when "view"
    Commands::PresetsHandler.show_preset(@controller, @user, @parts[2].to_i)
    answer_callback
  when "manage_edit"
    handle_preset_manage_edit
  when "manage_list"
    Commands::PresetsHandler.call(@controller, @user)
    answer_callback
  when "delete_confirm"
    handle_preset_delete_confirm
  when "delete_yes"
    handle_preset_delete_yes
  when "delete_no"
    Commands::PresetsHandler.call(@controller, @user)
    answer_callback
  when "save_yes"
    handle_preset_save_yes
  when "save_no"
    answer_callback
  when "replace"
    handle_preset_replace
  when "invitees_yes"
    handle_preset_invitees_yes
  when "invitees_no"
    handle_preset_invitees_no
  when "remove_invitee"
    handle_preset_remove_invitee
  when "add_invitee"
    handle_preset_add_invitee
  else
    answer_callback
  end
end
```

**Step 3: Implement each sub-handler as private methods**

```ruby
private

def handle_preset_select
  preset_id = @parts[2].to_i
  preset = @user.game_presets.includes(:location, :game_preset_invitees).find_by(id: preset_id)
  return answer_callback unless preset

  data = PresetService.build_game_data(preset)
  data[:preset_id] = preset_id
  @controller.write_fsm_state(@user.id, step: "preset_summary", data: data)

  summary = PresetService.preset_summary(preset, locale: @locale)
  @controller.send_message(
    @user.telegram_id,
    "#{I18n.t("bot.presets.summary_title", locale: @locale)}\n\n#{summary}\n#{I18n.t("bot.presets.change_anything", locale: @locale)}",
    reply_markup: TelegramMessageBuilder.preset_change_keyboard(locale: @locale)
  )
  answer_callback
end

def handle_preset_no_change
  state = @controller.read_fsm_state(@user.id)
  return answer_callback unless state

  @controller.write_fsm_state(@user.id, step: "preset_datetime", data: state[:data])
  cal = TelegramCalendar.start(locale: @locale, time_zone: @user.tz)
  @controller.send_message(@user.telegram_id, cal[:text], reply_markup: cal[:keyboard])
  answer_callback
end

def handle_preset_change
  state = @controller.read_fsm_state(@user.id)
  return answer_callback unless state

  preset_id = state[:data][:preset_id] || state[:data]["preset_id"]
  @controller.write_fsm_state(@user.id, step: "preset_edit_menu", data: state[:data])
  @controller.send_message(
    @user.telegram_id,
    I18n.t("bot.presets.select_field", locale: @locale),
    reply_markup: TelegramMessageBuilder.preset_edit_menu_keyboard(preset_id, locale: @locale)
  )
  answer_callback
end

def handle_preset_edit_field
  preset_id = @parts[2].to_i
  field = @parts[3]
  state = @controller.read_fsm_state(@user.id)
  return answer_callback unless state

  data = state[:data].merge(editing_preset_id: preset_id, editing_field: field)

  case field
  when "sport_type"
    @controller.write_fsm_state(@user.id, step: "preset_edit_sport_type", data: data)
    @controller.send_message(
      @user.telegram_id,
      I18n.t("bot.select_sport_type", locale: @locale),
      reply_markup: TelegramMessageBuilder.sport_type_keyboard(locale: @locale)
    )
  when "event_type"
    @controller.write_fsm_state(@user.id, step: "preset_edit_event_type", data: data)
    @controller.send_message(
      @user.telegram_id,
      I18n.t("bot.select_event_type", locale: @locale),
      reply_markup: TelegramMessageBuilder.event_type_keyboard(locale: @locale)
    )
  when "location"
    @controller.write_fsm_state(@user.id, step: "preset_edit_location", data: data)
    existing_locations = Location.where(organizer_id: @user.id)
    @controller.send_message(
      @user.telegram_id,
      I18n.t("bot.select_location", locale: @locale),
      reply_markup: TelegramMessageBuilder.location_keyboard(existing_locations, locale: @locale)
    )
  when "max_participants"
    @controller.write_fsm_state(@user.id, step: "preset_edit_max", data: data)
    @controller.send_message(@user.telegram_id, I18n.t("bot.enter_max_participants", locale: @locale))
  when "min_participants"
    @controller.write_fsm_state(@user.id, step: "preset_edit_min", data: data)
    @controller.send_message(@user.telegram_id, I18n.t("bot.enter_min_participants", max: data[:max_participants] || data["max_participants"], locale: @locale))
  when "visibility"
    @controller.write_fsm_state(@user.id, step: "preset_edit_visibility", data: data)
    @controller.send_message(
      @user.telegram_id,
      I18n.t("bot.select_visibility", locale: @locale),
      reply_markup: TelegramMessageBuilder.visibility_keyboard(locale: @locale)
    )
  when "invitees"
    preset = GamePreset.includes(:game_preset_invitees).find_by(id: preset_id)
    return answer_callback unless preset

    @controller.write_fsm_state(@user.id, step: "preset_edit_invitees", data: data)
    @controller.send_message(
      @user.telegram_id,
      I18n.t("bot.presets.field_invitees", locale: @locale),
      reply_markup: TelegramMessageBuilder.preset_invitees_edit_keyboard(preset, locale: @locale)
    )
  end
  answer_callback
end

def handle_preset_edit_done
  preset_id = @parts[2].to_i
  state = @controller.read_fsm_state(@user.id)
  return answer_callback unless state

  # Check if we're in manage mode or game-creation mode
  if state[:step]&.start_with?("preset_manage")
    # Management mode — save changes to the preset record
    preset = @user.game_presets.find_by(id: preset_id)
    if preset
      updatable = %i[sport_type event_type location_id max_participants min_participants visibility]
      attrs = state[:data].slice(*updatable.map(&:to_s)).transform_keys(&:to_sym)
      preset.update!(attrs) if attrs.any?
      preset.update!(name: PresetService.auto_name(
        sport_type: preset.sport_type,
        event_type: preset.event_type,
        location_name: preset.location.name,
        locale: @locale
      ))
      @controller.send_message(@user.telegram_id, I18n.t("bot.presets.preset_updated", locale: @locale))
    end
    @controller.clear_fsm_state(@user.id)
    Commands::PresetsHandler.call(@controller, @user)
  else
    # Game-creation mode — return to preset summary
    preset = @user.game_presets.includes(:location, :game_preset_invitees).find_by(id: preset_id)
    return answer_callback unless preset

    @controller.write_fsm_state(@user.id, step: "preset_summary", data: state[:data])
    summary = PresetService.preset_summary(preset, locale: @locale)
    @controller.send_message(
      @user.telegram_id,
      "#{I18n.t("bot.presets.summary_title", locale: @locale)}\n\n#{summary}\n#{I18n.t("bot.presets.change_anything", locale: @locale)}",
      reply_markup: TelegramMessageBuilder.preset_change_keyboard(locale: @locale)
    )
  end
  answer_callback
end

def handle_preset_manage_edit
  preset_id = @parts[2].to_i
  preset = @user.game_presets.find_by(id: preset_id)
  return answer_callback unless preset

  data = PresetService.build_game_data(preset).merge(editing_preset_id: preset_id)
  @controller.write_fsm_state(@user.id, step: "preset_manage_edit_menu", data: data)
  @controller.send_message(
    @user.telegram_id,
    I18n.t("bot.presets.select_field", locale: @locale),
    reply_markup: TelegramMessageBuilder.preset_edit_menu_keyboard(preset_id, locale: @locale)
  )
  answer_callback
end

def handle_preset_delete_confirm
  preset_id = @parts[2].to_i
  preset = @user.game_presets.find_by(id: preset_id)
  return answer_callback unless preset

  @controller.send_message(
    @user.telegram_id,
    I18n.t("bot.presets.delete_confirm", name: preset.name, locale: @locale),
    reply_markup: TelegramMessageBuilder.preset_delete_confirm_keyboard(preset_id, locale: @locale)
  )
  answer_callback
end

def handle_preset_delete_yes
  preset_id = @parts[2].to_i
  preset = @user.game_presets.find_by(id: preset_id)
  if preset
    PresetService.delete(preset)
    @controller.send_message(@user.telegram_id, I18n.t("bot.presets.preset_deleted", locale: @locale))
  end
  Commands::PresetsHandler.call(@controller, @user)
  answer_callback
end

def handle_preset_save_yes
  state = @controller.read_fsm_state(@user.id)
  return answer_callback unless state

  game_data = state[:data]
  presets = @user.game_presets

  if presets.count >= GamePreset::MAX_PRESETS_PER_ORGANIZER
    @controller.write_fsm_state(@user.id, step: "save_preset_replace", data: game_data)
    @controller.send_message(
      @user.telegram_id,
      I18n.t("bot.presets.preset_limit_replace", locale: @locale),
      reply_markup: TelegramMessageBuilder.preset_replace_keyboard(presets, locale: @locale)
    )
  else
    preset = PresetService.create_from_game_data(organizer: @user, game_data: game_data, locale: @locale)
    @controller.clear_fsm_state(@user.id)
    @controller.send_message(@user.telegram_id, I18n.t("bot.presets.preset_saved", name: preset.name, locale: @locale))
  end
  answer_callback
end

def handle_preset_replace
  preset_id = @parts[2].to_i
  old_preset = @user.game_presets.find_by(id: preset_id)
  return answer_callback unless old_preset

  state = @controller.read_fsm_state(@user.id)
  return answer_callback unless state

  preset = PresetService.replace(old_preset: old_preset, organizer: @user, game_data: state[:data], locale: @locale)
  @controller.clear_fsm_state(@user.id)
  @controller.send_message(@user.telegram_id, I18n.t("bot.presets.preset_replaced", locale: @locale))
  answer_callback
end

def handle_preset_invitees_yes
  state = @controller.read_fsm_state(@user.id)
  return answer_callback unless state

  game_data = state[:data]
  game_id = game_data[:created_game_id] || game_data["created_game_id"]
  preset_id = game_data[:preset_id] || game_data["preset_id"]
  game = Game.find_by(id: game_id)
  preset = GamePreset.includes(:game_preset_invitees).find_by(id: preset_id)

  if game && preset
    preset.game_preset_invitees.each do |inv|
      if inv.user_id
        invitee = User.find_by(id: inv.user_id)
        InvitationService.create(game: game, inviter: @user, invitee: invitee) if invitee
      else
        InvitationService.create_for_unknown_user(game: game, inviter: @user, invitee_username: inv.username)
      end
    end
  end

  @controller.clear_fsm_state(@user.id)
  answer_callback
end

def handle_preset_invitees_no
  @controller.clear_fsm_state(@user.id)
  answer_callback
end

def handle_preset_remove_invitee
  preset_id = @parts[2].to_i
  invitee_id = @parts[3].to_i
  preset = @user.game_presets.includes(:game_preset_invitees).find_by(id: preset_id)
  return answer_callback unless preset

  inv = preset.game_preset_invitees.find_by(id: invitee_id)
  if inv
    username = inv.username
    inv.destroy!
    @controller.send_message(@user.telegram_id, I18n.t("bot.presets.invitee_removed", username: username, locale: @locale))
  end

  preset.reload
  state = @controller.read_fsm_state(@user.id)
  @controller.send_message(
    @user.telegram_id,
    I18n.t("bot.presets.field_invitees", locale: @locale),
    reply_markup: TelegramMessageBuilder.preset_invitees_edit_keyboard(preset, locale: @locale)
  )
  answer_callback
end

def handle_preset_add_invitee
  preset_id = @parts[2].to_i
  state = @controller.read_fsm_state(@user.id)
  return answer_callback unless state

  data = state[:data].merge(editing_preset_id: preset_id)
  @controller.write_fsm_state(@user.id, step: "preset_add_invitee", data: data)
  @controller.send_message(@user.telegram_id, I18n.t("bot.presets.add_invitee_prompt", locale: @locale))
  answer_callback
end
```

**Step 3: Commit**

```bash
git add app/commands/callback_router.rb
git commit -m "feat: add preset callback handlers to CallbackRouter"
```

---

### Task 8: FsmHandler — preset text input steps

**Files:**
- Modify: `app/commands/fsm_handler.rb`

**Step 1: Add preset text input step routing**

Add these cases to the `case state[:step]` block in `FsmHandler.handle`:

```ruby
when "preset_datetime"
  handle_preset_datetime(controller, user, text, state[:data])
when "preset_edit_max"
  handle_preset_edit_max(controller, user, text, state[:data])
when "preset_edit_min"
  handle_preset_edit_min(controller, user, text, state[:data])
when "preset_edit_location_name"
  handle_preset_edit_location_name(controller, user, text, state[:data])
when "preset_add_invitee"
  handle_preset_add_invitee(controller, user, text, state[:data])
```

**Step 2: Implement the handlers**

Add these private methods to `FsmHandler`:

```ruby
def self.handle_preset_datetime(controller, user, text, data)
  locale = user.locale.to_sym
  scheduled_at = GameCreator.send(:parse_datetime, text, user.tz)

  unless scheduled_at
    controller.send_message(user.telegram_id, I18n.t("bot.invalid_datetime_format", locale: locale))
    return
  end

  unless scheduled_at > Game::MIN_HOURS_BEFORE_GAME.hours.from_now
    controller.send_message(user.telegram_id, I18n.t("bot.datetime_too_soon", hours: Game::MIN_HOURS_BEFORE_GAME, locale: locale))
    return
  end

  game_data = data.merge(scheduled_at: scheduled_at.iso8601)
  game = GameCreator.finish(user, controller, game_data)

  return unless game

  # Check for preset invitees
  preset_id = data[:preset_id] || data["preset_id"]
  preset = GamePreset.includes(:game_preset_invitees).find_by(id: preset_id) if preset_id

  if preset&.game_preset_invitees&.any?
    invitee_names = preset.game_preset_invitees.map { |i| "@#{i.username}" }.join(", ")
    fsm_data = data.merge(created_game_id: game.id)
    controller.write_fsm_state(user.id, step: "preset_confirm_invitees", data: fsm_data)
    controller.send_message(
      user.telegram_id,
      I18n.t("bot.presets.confirm_invitees", list: invitee_names, locale: locale),
      reply_markup: TelegramMessageBuilder.preset_confirm_invitees_keyboard(locale: locale)
    )
  end
end

def self.handle_preset_edit_max(controller, user, text, data)
  locale = user.locale.to_sym
  max = text.to_i
  unless max.between?(2, 100)
    controller.send_message(user.telegram_id, I18n.t("bot.invalid_max_participants", locale: locale))
    return
  end

  preset_id = data[:editing_preset_id] || data["editing_preset_id"]
  updated_data = data.merge(max_participants: max)

  # Check if in manage mode
  step = data[:editing_field] ? "preset_manage_edit_menu" : "preset_edit_menu"
  if controller.read_fsm_state(user.id)[:step]&.start_with?("preset_manage") || step.start_with?("preset_manage")
    preset = user.game_presets.find_by(id: preset_id)
    PresetService.update_field(preset, :max_participants, max) if preset
    controller.write_fsm_state(user.id, step: "preset_manage_edit_menu", data: updated_data)
  else
    controller.write_fsm_state(user.id, step: "preset_edit_menu", data: updated_data)
  end

  controller.send_message(
    user.telegram_id,
    I18n.t("bot.presets.select_field", locale: locale),
    reply_markup: TelegramMessageBuilder.preset_edit_menu_keyboard(preset_id, locale: locale)
  )
end

def self.handle_preset_edit_min(controller, user, text, data)
  locale = user.locale.to_sym
  min = text.to_i
  max = (data[:max_participants] || data["max_participants"]).to_i

  unless min.between?(1, max)
    controller.send_message(user.telegram_id, I18n.t("bot.invalid_min_participants", max: max, locale: locale))
    return
  end

  preset_id = data[:editing_preset_id] || data["editing_preset_id"]
  updated_data = data.merge(min_participants: min)

  if controller.read_fsm_state(user.id)[:step]&.start_with?("preset_manage") || data[:editing_field]
    preset = user.game_presets.find_by(id: preset_id)
    PresetService.update_field(preset, :min_participants, min) if preset
    controller.write_fsm_state(user.id, step: "preset_manage_edit_menu", data: updated_data)
  else
    controller.write_fsm_state(user.id, step: "preset_edit_menu", data: updated_data)
  end

  controller.send_message(
    user.telegram_id,
    I18n.t("bot.presets.select_field", locale: locale),
    reply_markup: TelegramMessageBuilder.preset_edit_menu_keyboard(preset_id, locale: locale)
  )
end

def self.handle_preset_edit_location_name(controller, user, text, data)
  locale = user.locale.to_sym
  location = Location.find_or_create_by!(organizer: user, name: text.strip)
  preset_id = data[:editing_preset_id] || data["editing_preset_id"]
  updated_data = data.merge(location_id: location.id)

  if controller.read_fsm_state(user.id)[:step]&.include?("manage")
    preset = user.game_presets.find_by(id: preset_id)
    PresetService.update_field(preset, :location_id, location.id) if preset
    controller.write_fsm_state(user.id, step: "preset_manage_edit_menu", data: updated_data)
  else
    controller.write_fsm_state(user.id, step: "preset_edit_menu", data: updated_data)
  end

  controller.send_message(
    user.telegram_id,
    I18n.t("bot.presets.select_field", locale: locale),
    reply_markup: TelegramMessageBuilder.preset_edit_menu_keyboard(preset_id, locale: locale)
  )
end

def self.handle_preset_add_invitee(controller, user, text, data)
  locale = user.locale.to_sym
  preset_id = data[:editing_preset_id] || data["editing_preset_id"]
  preset = user.game_presets.includes(:game_preset_invitees).find_by(id: preset_id)
  return unless preset

  username = text.delete_prefix("@").strip
  invitee = User.find_by(username: username)

  GamePresetInvitee.create!(
    game_preset: preset,
    user_id: invitee&.id,
    username: username
  )

  controller.send_message(user.telegram_id, I18n.t("bot.presets.invitee_added", username: username, locale: locale))

  preset.reload
  controller.write_fsm_state(user.id, step: "preset_edit_invitees", data: data)
  controller.send_message(
    user.telegram_id,
    I18n.t("bot.presets.field_invitees", locale: locale),
    reply_markup: TelegramMessageBuilder.preset_invitees_edit_keyboard(preset, locale: locale)
  )
end
```

**Step 3: Commit**

```bash
git add app/commands/fsm_handler.rb
git commit -m "feat: add preset text input handlers to FsmHandler"
```

---

### Task 9: NewGameHandler — preset choice on /newgame

**Files:**
- Modify: `app/commands/commands/new_game_handler.rb`

**Step 1: Modify NewGameHandler.call to check for presets**

Replace the current `GameCreator.start(user, controller)` call with preset-aware logic:

```ruby
module Commands
  class NewGameHandler
    def self.call(controller, user)
      locale = user.locale.to_sym

      unless user.organizer?
        controller.send_message(controller.from.id, I18n.t("bot.not_authorized", locale: locale))
        return
      end

      active_count = Game.active_for_organizer(user.id).count

      if active_count >= Game::ACTIVE_EVENTS_LIMIT
        send_limit_warning(controller, user, locale)
        return
      end

      presets = user.game_presets.includes(:location)
      if presets.any?
        controller.send_message(
          user.telegram_id,
          I18n.t("bot.presets.choose_prompt", locale: locale),
          reply_markup: TelegramMessageBuilder.choose_preset_keyboard(presets, locale: locale)
        )
      else
        start_fresh(controller, user)
      end
    end

    def self.start_fresh(controller, user)
      GameCreator.start(user, controller)
    end

    def self.send_limit_warning(controller, user, locale)
      active_games = Game.active_for_organizer(user.id).includes(:location).to_a

      buttons = active_games.map do |game|
        [Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          "🗄 #{game.title} — #{game.scheduled_at.in_time_zone(user.tz).strftime('%d.%m %H:%M')}",
          callback_data: "archive_game:#{game.id}"
        )]
      end

      controller.send_message(
        controller.from.id,
        I18n.t("bot.active_event_limit_reached", locale: locale),
        reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
      )
    end
  end
end
```

**Step 2: Commit**

```bash
git add app/commands/commands/new_game_handler.rb
git commit -m "feat: show preset choice when organizer has presets on /newgame"
```

---

### Task 10: GameCreator — save-as-preset prompt after game creation

**Files:**
- Modify: `app/services/game_creator.rb`

**Step 1: Add save-as-preset prompt after finish**

In `GameCreator.finish`, after the game is successfully created and the success message is sent, add the save-as-preset prompt. Modify the `finish` method to prompt save (only for normal game creation, not relaunch):

After line `game` (the return value inside the transaction), and before the `rescue`, add:

```ruby
# After the transaction block, prompt to save as preset (skip for relaunch)
unless data[:relaunch_game_id]
  controller.write_fsm_state(user.id, step: "save_preset_prompt", data: data.merge(location_id: game.location_id))
  controller.send_message(
    user.telegram_id,
    I18n.t("bot.presets.save_prompt", locale: locale),
    reply_markup: TelegramMessageBuilder.save_preset_keyboard(locale: locale)
  )
end
```

Note: The `controller.clear_fsm_state(user.id)` call inside the transaction needs to be moved — it should only clear for relaunch, or be removed and handled by the save-preset callback instead. For relaunch flow, clear immediately. For normal flow, the FSM state is cleared when the user answers the save prompt.

Specifically, change line 125 from:
```ruby
controller.clear_fsm_state(user.id)
```
to:
```ruby
controller.clear_fsm_state(user.id) if data[:relaunch_game_id]
```

**Step 2: Commit**

```bash
git add app/services/game_creator.rb
git commit -m "feat: prompt save-as-preset after normal game creation"
```

---

### Task 11: CallbackRouter — preset_datetime calendar integration

**Files:**
- Modify: `app/commands/callback_router.rb` — update `complete_calendar_selection` to handle `preset_datetime` step

**Step 1: Handle preset_datetime in calendar completion**

In the `complete_calendar_selection` method, update the step check and add a handler:

Change:
```ruby
return unless state && %w[datetime relaunch_datetime].include?(state[:step])
```
to:
```ruby
return unless state && %w[datetime relaunch_datetime preset_datetime].include?(state[:step])
```

Add a new `when` case in the `case state[:step]` block:

```ruby
when "preset_datetime"
  data = state[:data].merge(scheduled_at: datetime.iso8601)
  @controller.clear_fsm_state(@user.id)
  game = GameCreator.finish(@user, @controller, data)

  if game
    preset_id = data[:preset_id] || data["preset_id"]
    preset = GamePreset.includes(:game_preset_invitees).find_by(id: preset_id) if preset_id

    if preset&.game_preset_invitees&.any?
      invitee_names = preset.game_preset_invitees.map { |i| "@#{i.username}" }.join(", ")
      fsm_data = data.merge(created_game_id: game.id)
      @controller.write_fsm_state(@user.id, step: "preset_confirm_invitees", data: fsm_data)
      @controller.send_message(
        @user.telegram_id,
        I18n.t("bot.presets.confirm_invitees", list: invitee_names, locale: @locale),
        reply_markup: TelegramMessageBuilder.preset_confirm_invitees_keyboard(locale: @locale)
      )
    end
  end
```

**Step 2: Commit**

```bash
git add app/commands/callback_router.rb
git commit -m "feat: handle preset_datetime in calendar completion"
```

---

### Task 12: CallbackRouter — preset field edit callbacks via FSM

**Files:**
- Modify: `app/commands/callback_router.rb` — handle FSM callbacks for preset editing (sport_type, event_type, location, visibility selections via inline keyboards)

**Step 1: Update handle_fsm to route preset edit callbacks**

The existing `handle_fsm` method dispatches `fsm:sport_type:basketball` etc. to `GameCreator.handle_callback`. For preset editing, the FSM step will be `preset_edit_sport_type` etc., so these callbacks need to be intercepted.

Add to `handle_fsm`:

```ruby
def handle_fsm
  state = @controller.read_fsm_state(@user.id)

  if state && state[:step]&.start_with?("preset_edit_") || state && state[:step]&.start_with?("preset_manage_edit_")
    handle_preset_fsm_callback(state, @parts[1], @parts[2])
  else
    GameCreator.handle_callback(@user, @controller, @parts[1], @parts[2])
  end
  answer_callback
end
```

**Step 2: Implement handle_preset_fsm_callback**

```ruby
def handle_preset_fsm_callback(state, field, value)
  data = state[:data]
  preset_id = data[:editing_preset_id] || data["editing_preset_id"]
  is_manage = state[:step].include?("manage")

  case field
  when "sport_type"
    data = data.merge(sport_type: value)
  when "event_type"
    data = data.merge(event_type: value)
  when "location_id"
    if value == "new"
      step = is_manage ? "preset_manage_edit_location_name" : "preset_edit_location_name"
      @controller.write_fsm_state(@user.id, step: step, data: data)
      @controller.send_message(@user.telegram_id, I18n.t("bot.enter_location_name", locale: @locale))
      return
    else
      data = data.merge(location_id: value.to_i)
    end
  when "visibility"
    data = data.merge(visibility: value)
  end

  if is_manage
    preset = @user.game_presets.find_by(id: preset_id)
    if preset
      case field
      when "sport_type" then PresetService.update_field(preset, :sport_type, value)
      when "event_type" then PresetService.update_field(preset, :event_type, value)
      when "location_id" then PresetService.update_field(preset, :location_id, value.to_i)
      when "visibility" then PresetService.update_field(preset, :visibility, value)
      end
    end
    @controller.write_fsm_state(@user.id, step: "preset_manage_edit_menu", data: data)
  else
    @controller.write_fsm_state(@user.id, step: "preset_edit_menu", data: data)
  end

  @controller.send_message(
    @user.telegram_id,
    I18n.t("bot.presets.select_field", locale: @locale),
    reply_markup: TelegramMessageBuilder.preset_edit_menu_keyboard(preset_id, locale: @locale)
  )
end
```

**Step 3: Commit**

```bash
git add app/commands/callback_router.rb
git commit -m "feat: route FSM callbacks to preset edit handlers"
```

---

### Task 13: HelpHandler — add /presets to help text

**Files:**
- Modify: `app/commands/commands/help_handler.rb`

**Step 1: Add /presets line to help output**

Find the help handler and add the presets line. The help text is built from i18n keys, so the keys added in Task 4 should be sufficient. Just add the line in the handler method, likely after `newgame`:

```ruby
# Add after the newgame help line
text += "\n#{I18n.t("bot.help.presets", locale: locale)}" if user.organizer?
```

**Step 2: Commit**

```bash
git add app/commands/commands/help_handler.rb
git commit -m "feat: add /presets to help output for organizers"
```

---

### Task 14: Integration tests

**Files:**
- Create: `spec/services/preset_service_spec.rb` (already created in Task 3)
- Create: `spec/commands/presets_handler_spec.rb`
- Create: `spec/integration/preset_game_creation_spec.rb`

**Step 1: Write PresetsHandler spec**

```ruby
# spec/commands/presets_handler_spec.rb
require "rails_helper"

RSpec.describe Commands::PresetsHandler do
  let(:organizer) { create(:user, :organizer) }
  let(:location) { create(:location, organizer: organizer) }
  let(:controller) { instance_double("TelegramBotController") }

  before do
    allow(controller).to receive(:from).and_return(OpenStruct.new(id: organizer.telegram_id))
    allow(controller).to receive(:send_message)
  end

  describe ".call" do
    context "when organizer has no presets" do
      it "shows no presets message" do
        described_class.call(controller, organizer)
        expect(controller).to have_received(:send_message).with(
          organizer.telegram_id,
          I18n.t("bot.presets.no_presets", locale: :en)
        )
      end
    end

    context "when organizer has presets" do
      before { create(:game_preset, organizer: organizer, location: location) }

      it "shows preset list" do
        described_class.call(controller, organizer)
        expect(controller).to have_received(:send_message).with(
          organizer.telegram_id,
          I18n.t("bot.presets.preset_list_title", locale: :en),
          reply_markup: anything
        )
      end
    end

    context "when user is not organizer" do
      let(:participant) { create(:user) }

      it "shows not authorized message" do
        described_class.call(controller, participant)
        expect(controller).to have_received(:send_message).with(
          participant.telegram_id,
          I18n.t("bot.not_authorized", locale: :en)
        )
      end
    end
  end
end
```

**Step 2: Write integration test for preset game creation flow**

```ruby
# spec/integration/preset_game_creation_spec.rb
require "rails_helper"

RSpec.describe "Preset game creation flow" do
  let(:organizer) { create(:user, :organizer) }
  let(:location) { create(:location, organizer: organizer) }
  let!(:preset) { create(:game_preset, organizer: organizer, location: location) }
  let(:invitee) { create(:user, username: "player1") }
  let(:controller) { instance_double("TelegramBotController") }

  before do
    allow(controller).to receive(:from).and_return(OpenStruct.new(id: organizer.telegram_id))
    allow(controller).to receive(:send_message)
    allow(controller).to receive(:write_fsm_state)
    allow(controller).to receive(:read_fsm_state)
    allow(controller).to receive(:clear_fsm_state)
  end

  it "shows preset choice when organizer has presets" do
    Commands::NewGameHandler.call(controller, organizer)
    expect(controller).to have_received(:send_message).with(
      organizer.telegram_id,
      I18n.t("bot.presets.choose_prompt", locale: :en),
      reply_markup: anything
    )
  end

  it "skips preset choice when no presets exist" do
    preset.destroy!
    Commands::NewGameHandler.call(controller, organizer)
    expect(controller).to have_received(:send_message).with(
      organizer.telegram_id,
      I18n.t("bot.select_sport_type", locale: :en),
      reply_markup: anything
    )
  end

  describe "preset limit enforcement" do
    it "prevents creating more than 5 presets" do
      4.times { create(:game_preset, organizer: organizer, location: location) }
      sixth = build(:game_preset, organizer: organizer, location: location)
      expect(sixth).not_to be_valid
    end
  end
end
```

**Step 3: Run all tests**

Run: `bundle exec rspec spec/models/game_preset_spec.rb spec/services/preset_service_spec.rb spec/commands/presets_handler_spec.rb spec/integration/preset_game_creation_spec.rb`
Expected: All PASS.

**Step 4: Commit**

```bash
git add spec/
git commit -m "test: add preset handler and integration tests"
```

---

### Task 15: Full test suite run and cleanup

**Step 1: Run the full test suite**

Run: `bundle exec rspec`
Expected: All existing tests still pass, all new tests pass.

**Step 2: Fix any failures**

Address any test failures. Common issues:
- Factory associations may need `location` trait
- FSM state mocking may need updates in existing tests

**Step 3: Final commit**

```bash
git add -A
git commit -m "chore: fix any test suite issues from preset feature"
```
