class CreateLocations < ActiveRecord::Migration[7.2]
  def change
    create_table :locations do |t|
      t.references :organizer, null: false, foreign_key: { to_table: :users }
      t.string     :name,      null: false
      t.string     :address

      t.timestamps
    end

    add_index :locations, [:organizer_id, :name]
  end
end
