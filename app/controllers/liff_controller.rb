# The LIFF app's page (ADR 0024). Its hashed assets are files in public/liff with the usual
# one-year cache; this page isn't, so LINE revalidates it on every launch and picks up new
# builds. ActionController::Base, not ApplicationController: no sign-in and no allow_browser,
# so LINE's in-app browser can't be turned away.
class LiffController < ActionController::Base
  # Copied here by the Docker build from the LIFF app's dist/index.html.
  PAGE = Rails.root.join("app/views/liff/show.html")

  def show
    response.headers["Cache-Control"] = "no-cache"
    render file: PAGE, layout: false, content_type: "text/html"
  end
end
