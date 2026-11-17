# Loads the occasion from the token in the URL, like the website's GroupScoped. Members and
# expenses are always found through @group, so an id from another occasion is a 404.
module Api::V1::OccasionScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_group
  end

  private
    def set_group
      @group = Group.find_by!(token: params[:occasion_token])
    end

    # Member#claim_by leaves one of two errors; each has its own problem code (409).
    def render_claim_conflict(member)
      code = member.errors.added?(:base, :claimed_by_other) ? :claimed_by_other : :already_claimed_here
      render_problem code, status: :conflict
    end
end
