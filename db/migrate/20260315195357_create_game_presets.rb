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
