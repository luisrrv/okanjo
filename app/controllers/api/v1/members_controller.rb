class Api::V1::MembersController < Api::V1::BaseController
  include Api::V1::OccasionScoped

  # claim isn't a Member attribute, so Rails wouldn't wrap it by default.
  wrap_parameters include: %i[name claim]
  api_rate_limit to: 30, within: 1.minute, only: :create, name: "members", by: -> { Current.user.id }

  # With "claim": true the new member is also yours. If it can't be (you already have a member
  # here), the member isn't created either.
  def create
    attributes = params.expect(member: [ :name, :claim ])
    @member = Member.new(name: attributes[:name], group: @group)

    created = Member.transaction do
      raise ActiveRecord::Rollback unless @member.save && (!claim?(attributes) || @member.claim_by(Current.user))
      true
    end

    if created
      render :show, status: :created, location: api_v1_occasion_url(@group)
    elsif @member.errors.include?(:name)
      render_validation_failed @member
    else
      render_claim_conflict @member
    end
  end

  # Only members who haven't paid for anything and aren't in any split, as on the website.
  def destroy
    member = @group.members.find(params[:id])

    if member.destroy
      head :no_content
    else
      render_problem :member_in_use, status: :conflict
    end
  end

  private
    def claim?(attributes)
      ActiveModel::Type::Boolean.new.cast(attributes[:claim])
    end
end
