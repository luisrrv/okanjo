class GroupsController < ApplicationController
  allow_unauthenticated_access # occasions never need an account (ADR 0022)
  include CurrentMember

  rate_limit to: 10, within: 1.minute, only: :create

  def new
    @group = Group.new
    @group.members.build
    load_home_lists
  end

  def create
    @group = Group.new(group_params)

    if @group.save
      remember_member(@group.members.first)
      redirect_to @group, notice: t(".created")
    else
      load_home_lists
      render :new, status: :unprocessable_content
    end
  end

  def show
    @group = Group.find_by!(token: params[:token])
    @member = Member.new
    remember_group(@group)
  end

  private
    # Signed in: your account's occasions first, then this browser's others (ADR 0022).
    def load_home_lists
      @my_groups = authenticated? ? Current.user.groups.order(updated_at: :desc).includes(:members).to_a : []
      @recent_groups = recent_groups - @my_groups
    end

    def group_params
      params.expect(group: [ :name, members_attributes: [ [ :name ] ] ])
    end
end
