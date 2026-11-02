# "I'm this member" for this browser, stored in the signed cookie (ADR 0006).
class IdentitiesController < ApplicationController
  include GroupScoped
  include CurrentMember

  def create
    member = @group.members.find(params.expect(:member_id))
    remember_member(member)
    redirect_to @group, notice: t(".created", name: member.name)
  end

  def destroy
    forget_member(@group)
    redirect_to @group
  end
end
