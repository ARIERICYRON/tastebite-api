module Api
  module V1
    class NotificationsController < ApplicationController
      before_action :authenticate!

      # GET /api/v1/notifications
      def index
        notes = current_user.notifications.order(created_at: :desc).limit(50)
        render json: {
          unread_count: current_user.notifications.unread.count,
          notifications: notes.map { |n| note_json(n) }
        }
      end

      # POST /api/v1/notifications/read   (marks all read)
      def read
        current_user.notifications.unread.update_all(read_at: Time.current)
        render json: { unread_count: 0 }
      end

      private

      def note_json(n)
        target_exists = case n.notifiable_type
                        when "Recipe" then Recipe.visible_to(current_user).exists?(id: n.notifiable_id)
                        when "Post" then Post.exists?(id: n.notifiable_id)
                        else false
                        end
        {
          id: n.id, action: n.action, read: n.read_at.present?,
          created_at: n.created_at,
          actor: { id: n.actor.id, name: n.actor.name, handle: n.actor.handle },
          target_type: target_exists ? n.notifiable_type : nil, target_id: target_exists ? n.notifiable_id : nil
        }
      end
    end
  end
end
