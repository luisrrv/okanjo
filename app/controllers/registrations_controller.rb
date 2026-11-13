# Sign-up. The auth generator doesn't include one (ADR 0022).
class RegistrationsController < ApplicationController
  include CurrentMember

  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: t("rate_limited") }

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      start_new_session_for @user
      claim_remembered_members
      redirect_to after_authentication_url, notice: t(".created")
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def user_params
      params.expect(user: [ :email_address, :password, :password_confirmation ])
    end
end
