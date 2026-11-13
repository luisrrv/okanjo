require "rails_helper"

# The generator rejects connections without a login, which would stop live refresh
# for everyone signed out (ADR 0022).
RSpec.describe ApplicationCable::Connection, type: :channel do
  it "accepts a signed-out visitor" do
    connect

    expect(connection.current_user).to be_nil
  end

  it "identifies a logged-in user" do
    user = create(:user)
    cookies.signed[:session_id] = user.sessions.create!.id

    connect

    expect(connection.current_user).to eq(user)
  end
end
