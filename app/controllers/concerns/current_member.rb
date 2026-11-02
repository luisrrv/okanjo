# Remembers which member this browser is in each occasion, in a signed cookie
# of { group token => member id or nil }, most recently opened first (ADR 0006).
# Convenience only, not security: anyone can claim any member.
module CurrentMember
  extend ActiveSupport::Concern

  MAX_REMEMBERED = 50

  included do
    helper_method :current_member
  end

  private
    # The member this browser is in @group, or nil if unknown or since removed.
    def current_member
      return @current_member if defined?(@current_member)

      member_id = remembered_members[@group.token]
      @current_member = member_id && @group.members.find_by(id: member_id)
    end

    def remember_member(member)
      remember(member.group, member.id)
    end

    # Adds the occasion to this browser's recent list, keeping who you are in it.
    def remember_group(group)
      remember(group, remembered_members[group.token])
    end

    def forget_member(group)
      remember(group, nil)
    end

    # This browser's occasions, newest first. Forgets any that have been purged.
    def recent_groups
      tokens = remembered_members.keys
      groups = Group.where(token: tokens).includes(:members).index_by(&:token)
      write_remembered(remembered_members.slice(*groups.keys)) if groups.size < tokens.size
      groups.values_at(*tokens).compact
    end

    def remembered_members
      cookies.signed[:members].presence || {}
    end

    def remember(group, member_id)
      write_remembered({ group.token => member_id }.merge(remembered_members.except(group.token)))
    end

    def write_remembered(members)
      cookies.signed[:members] = { value: members.first(MAX_REMEMBERED).to_h, expires: 1.year, httponly: true }
    end
end
