# Signing in with LINE (ADR 0024): the LIFF app sends LINE's ID token, LINE confirms it, and the
# app issues its own token. With an email and password as well, it also links that email account,
# so both sign-ins reach the same User.
class Api::V1::LineSessionsController < Api::V1::BaseController
  skip_before_action :authenticate
  api_rate_limit to: 10, within: 3.minutes, name: "line-sign-in"

  rescue_from LineIdToken::Invalid do
    render_problem :invalid_line_token, status: :unauthorized
  end

  rescue_from LineIdToken::Unavailable do
    response.set_header("Retry-After", "30")
    render_problem :line_unavailable, status: :service_unavailable
  end

  def create
    line_user_id = LineIdToken.verify(params.expect(:id_token))

    if params.key?(:email_address) || params.key?(:password)
      link_email_account(line_user_id)
    else
      # Relies on the unique index, so two first sign-ins at once make one user.
      start_api_session_for User.create_or_find_by!(line_user_id:)
    end
  end

  private
    def link_email_account(line_user_id)
      email_address, password = params.expect(:email_address, :password)
      user = User.authenticate_by(email_address:, password:)
      line_holder = User.find_by(line_user_id:)

      if user.nil?
        render_problem :invalid_credentials, status: :unauthorized
      elsif user == line_holder
        start_api_session_for user
      elsif user.line_user_id?
        render_problem :email_account_linked_elsewhere, status: :conflict
      elsif line_holder&.email_address?
        render_problem :line_linked_elsewhere, status: :conflict
      else
        line_holder ? user.merge_line_account!(line_holder) : user.update!(line_user_id:)
        start_api_session_for user
      end
    end
end
