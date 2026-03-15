class CreateGamePresetInvitees < ActiveRecord::Migration[7.2]
  def change
    create_table :game_preset_invitees do |t|
      t.bigint :game_preset_id, null: false
      t.bigint :user_id
      t.string :username
      t.timestamps
    end

    add_index :game_preset_invitees, :game_preset_id
    add_index :game_preset_invitees, [:game_preset_id, :user_id], unique: true, where: "user_id IS NOT NULL"
    add_foreign_key :game_preset_invitees, :game_presets
    add_foreign_key :game_preset_invitees, :users
  end
end
