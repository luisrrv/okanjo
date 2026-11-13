require "rails_helper"

# Guards the backup decisions in ADR 0020 against careless edits to config/litestream.yml.
RSpec.describe "Litestream configuration" do
  def config
    YAML.load_file(Rails.root.join("config/litestream.yml"))
  end

  it "backs up only the primary production database" do
    expect(config["dbs"].map { |db| db["path"] }).to eq([ "storage/production.sqlite3" ])
  end

  it "keeps 7 days of backups, taking a snapshot every day" do
    expect(config["snapshot"]).to eq("interval" => "24h", "retention" => "168h")
  end

  it "uploads once a minute to the private Oracle bucket, with path-style requests" do
    replica = config["dbs"].first["replica"]

    expect(replica).to include(
      "type" => "s3", "bucket" => "okanjo-backups", "path" => "production",
      "region" => "ap-osaka-1", "force-path-style" => true, "sync-interval" => "1m"
    )
    expect(replica["endpoint"]).to end_with(".compat.objectstorage.ap-osaka-1.oraclecloud.com")
  end

  it "reads the keys from the environment, never from the file" do
    replica = config["dbs"].first["replica"]

    expect(replica.values_at("access-key-id", "secret-access-key"))
      .to eq([ "$LITESTREAM_ACCESS_KEY_ID", "$LITESTREAM_SECRET_ACCESS_KEY" ])
  end
end
