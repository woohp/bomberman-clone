class AddStatusToGame < ActiveRecord::Migration
  def change
    add_column :games, :status_cd, :integer
  end
end
