# Every API controller's parent (ADR 0023): no cookies, no CSRF, a bearer token on every
# request, and errors as RFC 9457 problem details.
class Api::V1::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  # Rails' default only raises TooManyRequests; API clients get a problem and Retry-After.
  def self.api_rate_limit(to:, within:, **options)
    rate_limit(to:, within:, **options, with: -> { render_rate_limited(within) })
  end

  before_action :authenticate

  # One budget per user across the whole API. Runs after authenticate, so the user is known;
  # sign-in has no user yet and counts by IP.
  api_rate_limit to: 300, within: 1.minute, scope: "api/v1", name: "requests",
                 by: -> { Current.user&.id || request.remote_ip }

  rescue_from ActiveRecord::RecordNotFound do
    render_problem :not_found, status: :not_found
  end

  rescue_from ActionController::ParameterMissing, ActionDispatch::Http::Parameters::ParseError do
    render_problem :bad_request, status: :bad_request
  end

  private
    def authenticate
      Current.session = authenticate_with_http_token { |token| Session.find_by_api_token(token) }
      request_bearer_authentication unless Current.session
    end

    # RFC 6750 §3: say which scheme to use, and flag a token that was sent but didn't verify.
    def request_bearer_authentication
      challenge = %(Bearer realm="warikan")
      challenge += %(, error="invalid_token") if request.authorization.present?
      response.set_header("WWW-Authenticate", challenge)
      render_problem :unauthorized, status: :unauthorized
    end

    def render_rate_limited(within)
      response.set_header("Retry-After", within.to_i.to_s)
      render_problem :rate_limited, status: :too_many_requests
    end

    # formats: :json because a body that fails to parse also loses the route's format default.
    def render_problem(code, status:, errors: nil)
      render "api/v1/problems/show", formats: :json, status:, content_type: "application/problem+json",
                                     locals: { code:, status: Rack::Utils.status_code(status), errors: }
    end
end
