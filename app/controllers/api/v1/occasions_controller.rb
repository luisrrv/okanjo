# An occasion is a Group (ADR 0023, D3). Reading returns the whole thing, computed on the
# server, with an ETag so a client that polls gets a 304 when nothing changed (D4).
class Api::V1::OccasionsController < Api::V1::BaseController
  # Part of the ETag: bump it when the occasion's JSON shape changes, so clients don't keep a
  # 304 for an old shape. ActionController::API doesn't mix template digests into ETags.
  SHAPE_VERSION = 1

  api_rate_limit to: 10, within: 1.minute, only: :create, name: "occasions", by: -> { Current.user.id }

  def show
    @group = Group.find_by!(token: params[:token])
    load_occasion if stale?(etag: [ SHAPE_VERSION, @group, Current.user ], last_modified: @group.updated_at)
  end

  # Creates the occasion with its first member, claimed by you, as the website does when
  # you're signed in (ADR 0022).
  def create
    attributes = params.expect(occasion: [ :name, :member_name ])
    @group = Group.new(name: attributes[:name], members_attributes: [ { name: attributes[:member_name] } ])

    if @group.save
      @group.members.first.claim_by(Current.user)
      load_occasion
      render :show, status: :created, location: api_v1_occasion_url(@group)
    else
      render_validation_failed @group, fields: { "members.name": :member_name }
    end
  end

  private
    def load_occasion
      @members = @group.members.order(:id)
      @removable_ids = @group.members.removable.ids
      @expenses = @group.expenses.order(created_at: :desc).includes(:participations)
      @balance_sheet = BalanceSheet.new(@group)
      @settlement = Settlement.new(@balance_sheet.balances)
    end
end
