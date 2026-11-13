module ApplicationCable
  # The generator rejects connections without a signed-in user. Occasions are open to anyone
  # with the link (ADR 0022), so everyone connects and gets live refresh (ADR 0019); the user
  # is identified only when there is one.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = Session.find_by(id: cookies.signed[:session_id])&.user
    end
  end
end
