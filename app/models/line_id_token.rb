require "net/http"

# Checks an ID token from LIFF with LINE's verify endpoint and returns the LINE user ID (ADR
# 0024, D3). LINE checks the signature, expiry and audience; this app never handles LINE's keys.
# Runs once per LINE sign-in; every other request uses the app's own token (ADR 0023).
class LineIdToken
  # LINE rejected the token: expired, for another channel, or forged.
  class Invalid < StandardError; end
  # LINE couldn't be asked: a timeout, a network error, or an unexpected answer.
  class Unavailable < StandardError; end

  VERIFY_URL = URI("https://api.line.me/oauth2/v2.1/verify")

  def self.verify(id_token)
    response = Net::HTTP.start(VERIFY_URL.host, VERIFY_URL.port, use_ssl: true, open_timeout: 3, read_timeout: 5) do |http|
      http.post(VERIFY_URL.path, URI.encode_www_form(id_token:, client_id: channel_id))
    end

    case response
    when Net::HTTPOK then JSON.parse(response.body).fetch("sub")
    when Net::HTTPBadRequest then raise Invalid, response.body
    else raise Unavailable, "LINE answered #{response.code}"
    end
  rescue Timeout::Error, SystemCallError, SocketError, OpenSSL::SSL::SSLError, JSON::ParserError, KeyError => error
    raise Unavailable, error.message
  end

  # The LINE Login channel that owns the LIFF app. Public, so plain configuration, not a secret.
  def self.channel_id
    Rails.configuration.x.line.channel_id.presence or raise "LINE_CHANNEL_ID isn't set"
  end
end
