json.partial! "api/v1/members/member", member: @member, removable: @group.members.removable.exists?(@member.id)
