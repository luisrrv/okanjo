class Session < ApplicationRecord
  # API tokens are signed session ids (ADR 0023): nothing secret is stored, and destroying the
  # session cancels its token.
  API_TOKEN_TTL = 30.days

  belongs_to :user

  # Nil when the token is forged, expired, signed for another purpose, or its session is gone.
  def self.find_by_api_token(token)
    find_signed(token, purpose: :api)
  end

  def api_token(expires_at:)
    signed_id(purpose: :api, expires_at:)
  end
end
