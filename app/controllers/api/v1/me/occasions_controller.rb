# Your occasions: the ones where your account holds a member (ADR 0022), most recently
# changed first, as on the website's home page.
class Api::V1::Me::OccasionsController < Api::V1::BaseController
  def index
    @groups = Current.user.groups.order(updated_at: :desc).includes(:members)
  end
end
