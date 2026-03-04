class CreateInvitations < ActiveRecord::Migration[7.2]
  def change
    create_table :invitations do |t|
      t.references :game,    null: false, foreign_key: true
      t.references :inviter, null: false, foreign_key: { to_table: :users }
      t.references :invitee, null: false, foreign_key: { to_table: :users }
      t.integer    :status,  null: false, default: 0

      t.timestamps
    end

    add_index :invitations, [:game_id, :invitee_id], unique: true
  end
end
