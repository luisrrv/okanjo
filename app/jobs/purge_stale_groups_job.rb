# Deletes occasions nobody has changed for longer than Group::RETENTION (ADR 0012, 0016).
# delete_all on purpose: the database cascades remove members, expenses and split entries
# in one statement, and no callbacks run, so nothing broadcasts for a dead occasion.
class PurgeStaleGroupsJob < ApplicationJob
  queue_as :default

  def perform
    purged = Group.stale.delete_all
    Rails.logger.info("Purged #{purged} stale occasions")
  end
end
