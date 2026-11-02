class GroupsController < ApplicationController
  include CurrentMember

  rate_limit to: 10, within: 1.minute, only: :create

  def new
    @group = Group.new
    @group.members.build
    @recent_groups = recent_groups
  end

  def create
    @group = Group.new(group_params)

    if @group.save
      remember_member(@group.members.first)
      redirect_to @group, notice: t(".created")
    else
      @recent_groups = recent_groups
      render :new, status: :unprocessable_content
    end
  end

  def show
    @group = Group.find_by!(token: params[:token])
    @member = Member.new
    remember_group(@group)
  end

  private
    def group_params
      params.expect(group: [ :name, members_attributes: [ [ :name ] ] ])
    end
end
