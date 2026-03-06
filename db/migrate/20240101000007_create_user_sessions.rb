class CreateUserSessions < ActiveRecord::Migration[7.2]
  def change
    create_table :user_sessions do |t|
      t.references :user,  null: false, foreign_key: true
      t.string     :state
      t.jsonb      :data,  null: false, default: {}

      t.timestamps
    end

    # add_index :user_sessions, :user_id, unique: true
  end
end
