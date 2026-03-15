class AddUniqueIndexForUnknownUserInvitations < ActiveRecord::Migration[7.2]
  def change
    add_index :invitations, [:game_id, :invitee_username],
              unique: true,
              where: "invitee_id IS NULL",
              name: "index_invitations_on_game_and_username_for_unknown"
  end
end
