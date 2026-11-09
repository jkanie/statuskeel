module ApplicationCable
  # Visitors of the public status page connect without signing in. They can only follow
  # streams whose signed names the server rendered for them (Turbo::StreamsChannel checks that).
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_signed_in_user
    end

    private
      def find_signed_in_user
        Session.find_by(id: cookies.signed[:session_id])&.user if cookies.signed[:session_id]
      end
  end
end
