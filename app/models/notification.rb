class Notification < ApplicationRecord
  belongs_to :user            # recipient
  belongs_to :actor, class_name: "User"

  scope :unread, -> { where(read_at: nil) }

  # Helper: create a notification unless you're acting on yourself
  def self.notify(recipient:, actor:, action:, notifiable: nil)
    return if recipient.id == actor.id
    create(
      user: recipient, actor: actor, action: action,
      notifiable_type: notifiable&.class&.name,
      notifiable_id: notifiable&.id
    )
  end
end
