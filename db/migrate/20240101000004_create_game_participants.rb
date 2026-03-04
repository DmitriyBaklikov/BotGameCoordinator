class CreateGameParticipants < ActiveRecord::Migration[7.2]
  def change
    create_table :game_participants do |t|
      t.references :game,                 null: false, foreign_key: true
      t.references :user,                 null: false, foreign_key: true
      t.integer    :status,               null: false, default: 0
      t.boolean    :invited_by_organizer, null: false, default: false
      t.boolean    :notified_reserve,     null: false, default: false

      t.timestamps
    end

    add_index :game_participants, [:game_id, :user_id], unique: true
    add_index :game_participants, [:game_id, :status]
  end
end
