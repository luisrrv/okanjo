# Remembers which member this browser is in each occasion, in a signed cookie
# of { group token => member id }, newest first (ADR 0006). Convenience only,
# not security: anyone can claim any member.
module CurrentMember
  extend ActiveSupport::Concern

  MAX_REMEMBERED = 50

  private
    def remembered_members
      cookies.signed[:members].presence || {}
    end

    def remember_member(member)
      token = member.group.token
      write_remembered({ token => member.id }.merge(remembered_members.except(token)))
    end

    # This browser's occasions, newest first. Forgets any that have been purged.
    def recent_groups
      tokens = remembered_members.keys
      groups = Group.where(token: tokens).includes(:members).index_by(&:token)
      write_remembered(remembered_members.slice(*groups.keys)) if groups.size < tokens.size
      groups.values_at(*tokens).compact
    end

    def write_remembered(members)
      cookies.signed[:members] = { value: members.first(MAX_REMEMBERED).to_h, expires: 1.year, httponly: true }
    end
end
