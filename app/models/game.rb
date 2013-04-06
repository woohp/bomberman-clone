class Game < ActiveRecord::Base
	as_enum :status, [:waiting, :in_progress, :done]

  belongs_to :player1, class_name: "User"
  belongs_to :player2, class_name: "User"
  belongs_to :player3, class_name: "User"
  belongs_to :player4, class_name: "User"

  validates :status_cd, presence: true
  validates :player1_id, presence: true
end
