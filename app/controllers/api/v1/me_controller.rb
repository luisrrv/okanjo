# Who the token belongs to. Lets a client check a stored token is still good.
class Api::V1::MeController < Api::V1::BaseController
  def show
    @user = Current.user
  end
end
