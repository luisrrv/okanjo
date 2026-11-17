# claimed: any account holds this member. mine: yours does. Other users never appear.
json.id member.id
json.name member.name
json.claimed member.user_id.present?
json.mine member.user_id == Current.user.id
json.removable removable
