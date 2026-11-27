# Chrome 158 rejects "*" as the origin of Storage.clearDataForOrigin ("* is not a valid URL"),
# which Capybara 3.40.0 sends from ChromeDriver#reset! between examples, so every system spec
# failed in teardown. When Chrome rejects it, clear cookies browser-wide and storage for the
# app's own origin instead. Older Chrome never reaches the rescue.
# Delete this file once a Capybara release fixes it:
# https://github.com/teamcapybara/capybara/issues/2865
module CapybaraChrome158StorageClear
  private

  def execute_cdp(cmd, params = {})
    super
  rescue Selenium::WebDriver::Error::InvalidArgumentError
    raise unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

    super("Network.clearBrowserCookies")
    app_origin = Capybara.current_session.server&.base_url
    super(cmd, params.merge(origin: app_origin)) if app_origin
  end
end

Capybara::Selenium::Driver::ChromeDriver.prepend(CapybaraChrome158StorageClear)
