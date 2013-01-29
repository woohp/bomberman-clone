class UsersController < ApplicationController
  def new
    @user = User.new
  end

  def create
    params[:user][:email] = nil if params[:user][:email].blank?
    @user = User.new params[:user]
    if @user.save
      redirect_to root_url, notice: "Signed up!"
    else
      render :new
    end
  end
end
