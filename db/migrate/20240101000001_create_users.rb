class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.bigint   :telegram_id,  null: false
      t.string   :username
      t.string   :first_name
      t.string   :last_name
      t.integer  :role,         null: false, default: 0
      t.string   :locale,       null: false, default: "en"

      t.timestamps
    end

    add_index :users, :telegram_id, unique: true
  end
end
