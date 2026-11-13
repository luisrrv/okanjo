# "I'm this member" for this browser, stored in the signed cookie (ADR 0006).
class IdentitiesController < ApplicationController
  allow_unauthenticated_access # occasions never need an account (ADR 0022)
  include GroupScoped
  include CurrentMember

  def create
    member = @group.members.find(params.expect(:member_id))
    if remember_member(member)
      redirect_to @group, notice: t(".created", name: member.name)
    else
      redirect_to @group, alert: member.errors.full_messages.to_sentence
    end
  end

  def destroy
    forget_member(@group)
    redirect_to @group
  end
end
