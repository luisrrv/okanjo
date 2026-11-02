require "rails_helper"
require "fugit" # Solid Queue's schedule parser

RSpec.describe PurgeStaleGroupsJob, type: :job do
  def occasion_last_changed(time)
    travel_to(time) { create(:expense).group }
  end

  it "deletes occasions untouched for more than 30 days, with everything in them" do
    stale = occasion_last_changed(31.days.ago)

    expect { PurgeStaleGroupsJob.perform_now }
      .to change(Group, :count).by(-1)
      .and change(Member, :count).by(-1)
      .and change(Expense, :count).by(-1)
      .and change(Participation, :count).by(-1)
    expect(Group.exists?(stale.id)).to be(false)
  end

  it "keeps occasions changed within 30 days" do
    recent = occasion_last_changed(29.days.ago)

    PurgeStaleGroupsJob.perform_now

    expect(Group.exists?(recent.id)).to be(true)
  end

  it "keeps an occasion exactly at the 30-day mark, so it's never deleted before its shown date" do
    now = Time.current.change(usec: 0)
    boundary = create(:group)
    boundary.update_column(:updated_at, now - 30.days)

    travel_to(now) { PurgeStaleGroupsJob.perform_now }

    expect(Group.exists?(boundary.id)).to be(true)
  end

  it "counts any change as activity, resetting the clock" do
    group = occasion_last_changed(31.days.ago)

    create(:member, group: group)
    PurgeStaleGroupsJob.perform_now

    expect(Group.exists?(group.id)).to be(true)
  end

  it "runs every day at 4am Japan time in production" do
    task = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).dig("production", "purge_stale_groups")
    schedule = Fugit.parse(task["schedule"])

    expect(task["class"]).to eq("PurgeStaleGroupsJob")
    expect(schedule.next_time(Time.utc(2026, 11, 2, 12, 0)).to_t.in_time_zone("Asia/Tokyo"))
      .to eq(Time.find_zone("Asia/Tokyo").local(2026, 11, 3, 4, 0))
  end
end
