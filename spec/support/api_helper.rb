# Signs in through the real API endpoint and sends JSON, so specs call the API the way a
# client does.
module ApiHelper
  def api_sign_in(user, password: "password")
    post api_v1_session_path, params: { email_address: user.email_address, password: }, as: :json
    response.parsed_body.fetch("token")
  end

  def bearer(token)
    { "Authorization" => "Bearer #{token}" }
  end

  def problem_code
    response.parsed_body["code"]
  end
end

RSpec.configure do |config|
  config.include ApiHelper, type: :request
end
