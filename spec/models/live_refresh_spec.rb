require "rails_helper"

# Every change to an occasion broadcasts one page refresh to its viewers (ADR 0019).
# In production refreshes are debounced by 0.5s; turbo-rails uses an immediate
# debouncer in tests, so the job is enqueued as soon as the change commits.
RSpec.describe "Live refresh", type: :model do
  include ActiveJob::TestHelper

  # Refresh jobs enqueued for this occasion's stream (named by its GlobalID).
  def refreshes_for(group)
    enqueued_jobs.count do |job|
      job["job_class"] == "Turbo::Streams::BroadcastStreamJob" && job["arguments"].first == group.to_gid_param
    end
  end

  def occasion_with_a_member
    group = create(:group)
    member = create(:member, group: group)
    clear_enqueued_jobs # ignore the refreshes from setting up
    [ group, member ]
  end

  it "broadcasts when an expense is added, through the group being touched" do
    group, payer = occasion_with_a_member

    create(:expense, group: group, payer: payer)

    expect(refreshes_for(group)).to eq(1)
  end

  it "broadcasts when someone is removed from a split" do
    group, payer = occasion_with_a_member
    guest = create(:member, group: group)
    expense = create(:expense, group: group, payer: payer, members: [ payer, guest ])
    clear_enqueued_jobs

    expense.update!(member_ids: [ payer.id ])

    expect(refreshes_for(group)).to eq(1)
  end

  it "broadcasts when a member is added" do
    group, _member = occasion_with_a_member

    create(:member, group: group)

    expect(refreshes_for(group)).to eq(1)
  end
end
