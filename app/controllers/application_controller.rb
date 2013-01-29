class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :initialize_bootstrap_data

  def initialize_bootstrap_data
    @bootstrap_data = {
      current_user: current_user
    }
  end
end
