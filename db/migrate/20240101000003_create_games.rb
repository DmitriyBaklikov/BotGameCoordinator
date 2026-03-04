class CreateGames < ActiveRecord::Migration[7.2]
  def change
    create_table :games do |t|
      t.references :organizer,       null: false, foreign_key: { to_table: :users }
      t.references :location,        null: false, foreign_key: true
      t.integer    :sport_type,       null: false
      t.integer    :event_type,       null: false
      t.string     :title,            null: false
      t.datetime   :scheduled_at,     null: false
      t.integer    :max_participants,  null: false
      t.integer    :min_participants,  null: false
      t.integer    :status,            null: false, default: 0
      t.integer    :visibility,        null: false, default: 0
      t.bigint     :chat_id
      t.bigint     :message_id

      t.timestamps
    end

    add_index :games, [:organizer_id, :status]
    add_index :games, [:status, :scheduled_at]
    add_index :games, [:visibility, :status]
  end
end
