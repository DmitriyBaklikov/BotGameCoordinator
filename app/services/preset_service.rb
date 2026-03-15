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
