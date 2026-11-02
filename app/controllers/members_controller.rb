class MembersController < ApplicationController
  include GroupScoped
  include CurrentMember

  rate_limit to: 30, within: 1.minute, only: :create

  def create
    # Member.new, not @group.members.new: an invalid member must not show up in
    # the member list when the occasion page is re-rendered.
    @member = Member.new(member_params.merge(group: @group))

    if @member.save
      remember_member(@member) if params[:me].present?
      redirect_to @group, notice: t(".created", name: @member.name)
    else
      render "groups/show", status: :unprocessable_content
    end
  end

  def destroy
    member = @group.members.find(params[:id])

    if member.destroy
      redirect_to @group, notice: t(".destroyed", name: member.name)
    else
      redirect_to @group, alert: member.errors.full_messages.to_sentence
    end
  end

  private
    def member_params
      params.expect(member: [ :name ])
    end
end
