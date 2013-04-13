class AddWinningsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :wins, :integer
    add_column :users, :loses, :integer
  end
end
