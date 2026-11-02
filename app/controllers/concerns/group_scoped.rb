# Loads the occasion from the token in the URL. Records inside it are always found
# through @group, so an id from another occasion is a 404, never a leak.
module GroupScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_group
  end

  private
    def set_group
      @group = Group.find_by!(token: params[:group_token])
    end
end
