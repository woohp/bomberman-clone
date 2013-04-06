class CreateGames < ActiveRecord::Migration
  def change
    create_table :games do |t|
      t.references :player1
      t.references :player2
      t.references :player3
      t.references :player4

      t.timestamps
    end
    add_index :games, :player1_id
    add_index :games, :player2_id
    add_index :games, :player3_id
    add_index :games, :player4_id
  end
end
