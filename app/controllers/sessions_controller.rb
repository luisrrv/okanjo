class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: t("rate_limited") }

  def new
  end

  def create
    # Top-level scalar fields, so permit, not expect: expect is for a nested hash under a
    # root key, and permit already drops anything that isn't a scalar.
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: t(".invalid")
    end
  end

  def destroy
    terminate_session
    # Who you were in each occasion lives in the account now; don't leave it for the next
    # person on a shared device (ADR 0022).
    cookies.delete(:members)
    redirect_to root_path, status: :see_other
  end
end
