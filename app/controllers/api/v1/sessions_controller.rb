# Signing in trades an email and password for a bearer token; signing out cancels it
# (ADR 0023). The token is the session's signed id, so nothing secret is stored.
class Api::V1::SessionsController < Api::V1::BaseController
  skip_before_action :authenticate, only: :create
  api_rate_limit to: 10, within: 3.minutes, only: :create, name: "sign-in"

  def create
    email_address, password = params.expect(:email_address, :password)

    if user = User.authenticate_by(email_address:, password:)
      @session = user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
      @expires_at = Session::API_TOKEN_TTL.from_now
      render :create, status: :created, location: api_v1_me_url
    else
      render_problem :invalid_credentials, status: :unauthorized
    end
  end

  def destroy
    Current.session.destroy
    head :no_content
  end
end
