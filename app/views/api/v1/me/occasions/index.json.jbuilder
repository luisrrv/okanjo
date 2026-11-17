json.occasions @groups do |group|
  json.token group.token
  json.name group.name
  json.my_member_id group.members.find { |member| member.user_id == Current.user.id }.id
  json.member_count group.members.size
  json.deletion_date group.deletion_date
  json.updated_at group.updated_at.iso8601
end
