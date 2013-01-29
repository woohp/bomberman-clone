class User < ActiveRecord::Base
  authenticates_with_sorcery!

  attr_accessible :username, :email, :password, :password_confirmation

  validates :username, presence: true, uniqueness: true
  validates :password, presence: true, on: :create, confirmation: true
  validates :email, uniqueness: true, allow_nil: true
end
