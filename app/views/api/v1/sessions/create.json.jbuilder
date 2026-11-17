json.token @session.api_token(expires_at: @expires_at)
json.expires_at @expires_at.iso8601
json.user do
  json.partial! "api/v1/users/user", user: @session.user
end
