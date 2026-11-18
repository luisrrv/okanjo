require "rails_helper"

# Net::HTTP is stubbed, so these never call LINE.
RSpec.describe LineIdToken do
  def line_answers(response)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:post).and_return(response)
    http
  end

  def http_response(klass, code, body)
    klass.new("1.1", code, "").tap { |response| allow(response).to receive(:body).and_return(body) }
  end

  it "asks LINE about the token for this channel, and returns the LINE user ID" do
    http = line_answers(http_response(Net::HTTPOK, "200", { sub: "U1234", aud: "1234567890" }.to_json))

    expect(described_class.verify("id-token")).to eq("U1234")
    expect(http).to have_received(:post).with("/oauth2/v2.1/verify", "id_token=id-token&client_id=1234567890")
  end

  it "says the token is invalid when LINE rejects it" do
    line_answers(http_response(Net::HTTPBadRequest, "400", { error: "invalid_request", error_description: "IdToken expired." }.to_json))

    expect { described_class.verify("expired") }.to raise_error(LineIdToken::Invalid)
  end

  it "says LINE is unavailable on an unexpected answer" do
    line_answers(http_response(Net::HTTPInternalServerError, "500", ""))

    expect { described_class.verify("id-token") }.to raise_error(LineIdToken::Unavailable)
  end

  it "says LINE is unavailable when it doesn't answer in time" do
    allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)

    expect { described_class.verify("id-token") }.to raise_error(LineIdToken::Unavailable)
  end
end
