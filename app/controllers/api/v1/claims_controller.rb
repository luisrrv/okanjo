# Linking a member to your account (ADR 0022). A claim is about listing, not access: it puts
# the occasion in your list, and anyone with the link can still act as any member.
class Api::V1::ClaimsController < Api::V1::BaseController
  include Api::V1::OccasionScoped

  before_action :set_member

  # Claiming a member you already hold is a no-op 200.
  def update
    if @member.claim_by(Current.user)
      render "api/v1/members/show"
    else
      render_claim_conflict @member
    end
  end

  # A 404 when it isn't yours, so it doesn't reveal whether someone else holds it.
  def destroy
    if @member.release_by(Current.user)
      head :no_content
    else
      render_problem :not_found, status: :not_found
    end
  end

  private
    def set_member
      @member = @group.members.find(params[:member_id])
    end
end
