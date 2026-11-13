# Remembers which member this browser is in each occasion, in a signed cookie
# of { group token => member id or nil }, most recently opened first (ADR 0006).
# Convenience only, not security: anyone can claim any member.
#
# When signed in, the account's member comes first, and choosing a member links it to the
# account (ADR 0022). Authentication's resume_session only runs when something asks, so this
# goes through authenticated? before reading Current.user.
module CurrentMember
  extend ActiveSupport::Concern

  MAX_REMEMBERED = 50

  included do
    helper_method :current_member
  end

  private
    # Who you are in @group: your account's member, else the one this browser remembers,
    # else nil.
    def current_member
      return @current_member if defined?(@current_member)

      @current_member = account_member || remembered_member
    end

    # Remembers the member in this browser and, when signed in, links it to the account.
    # False (with errors on the member) if another account already holds it.
    def remember_member(member)
      return false if authenticated? && !member.claim_by(Current.user)

      remember(member.group, member.id)
      true
    end

    # After signing in or up: link the members this browser remembers to the account,
    # skipping any the account can't take.
    def claim_remembered_members
      Member.where(id: remembered_members.values.compact).find_each do |member|
        member.claim_by(Current.user)
      end
    end

    # Adds the occasion to this browser's recent list, keeping who you are in it.
    def remember_group(group)
      remember(group, remembered_members[group.token])
    end

    def forget_member(group)
      account_member(group)&.release_by(Current.user)
      remember(group, nil)
    end

    # This browser's occasions, newest first. Forgets any that have been purged.
    def recent_groups
      tokens = remembered_members.keys
      groups = Group.where(token: tokens).includes(:members).index_by(&:token)
      write_remembered(remembered_members.slice(*groups.keys)) if groups.size < tokens.size
      groups.values_at(*tokens).compact
    end

    def account_member(group = @group)
      group.members.find_by(user: Current.user) if authenticated?
    end

    def remembered_member
      member_id = remembered_members[@group.token]
      member_id && @group.members.find_by(id: member_id)
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
