module GroupsHelper
  # The occasion's name, or its creation date when it has none.
  def group_title(group)
    group.name || l(group.created_at.to_date, format: :long)
  end
end
