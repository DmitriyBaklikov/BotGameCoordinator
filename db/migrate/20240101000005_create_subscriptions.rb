class CreateSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :subscriptions do |t|
      t.references :subscriber, null: false, foreign_key: { to_table: :users }
      t.references :organizer,  null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :subscriptions, [:subscriber_id, :organizer_id], unique: true
  end
end
