class AddTokenAndInviteeUsernameToInvitations < ActiveRecord::Migration[7.2]
  def up
    add_column :invitations, :token, :string
    add_column :invitations, :invitee_username, :string

    # Backfill existing invitations with UUID tokens
    execute <<-SQL
      UPDATE invitations SET token = gen_random_uuid()::text WHERE token IS NULL
    SQL

    change_column_null :invitations, :token, false
    add_index :invitations, :token, unique: true

    # Make invitee_id nullable (was NOT NULL)
    change_column_null :invitations, :invitee_id, true
  end

  def down
    remove_index :invitations, :token
    remove_column :invitations, :token
    remove_column :invitations, :invitee_username
    change_column_null :invitations, :invitee_id, false
  end
end
