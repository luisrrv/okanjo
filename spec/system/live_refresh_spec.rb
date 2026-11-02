require "rails_helper"

# Another viewer's change reaches this page as a Turbo refresh that morphs it (ADR 0019).
# The test cable adapter doesn't reach the browser, so each example makes the change on
# the server and then triggers the same refresh the broadcast would.
RSpec.describe "Live refresh", type: :system do
  def refresh_as_if_broadcast
    execute_script("Turbo.session.refresh(location.href)")
  end

  it "shows the other viewer's change without wiping what you're typing" do
    group = create(:group, name: "飲み会")
    create(:member, group: group, name: "Aki")
    visit group_path(group)
    within("#members") { fill_in "名前", with: "入力中" }

    create(:member, group: group, name: "Ben")
    refresh_as_if_broadcast

    within("#members") do
      expect(page).to have_content("Ben")
      expect(page).to have_field("名前", with: "入力中")
    end
  end

  it "still clears the field after your own submit" do
    group = create(:group)
    create(:member, group: group, name: "Aki")
    visit group_path(group)

    within("#members") do
      fill_in "名前", with: "Chie"
      click_on "追加"
    end

    expect(page).to have_content("Chieさんを追加しました")
    within("#members") { expect(page).to have_field("名前", with: "") }
  end
end
