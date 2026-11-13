# Logs in through the real sessions endpoint, so specs exercise what users do.
module SignInHelper
  def sign_in_as(user, password: "password")
    post session_path, params: { email_address: user.email_address, password: }
  end
end

RSpec.configure do |config|
  config.include SignInHelper, type: :request
end
