class Chat < ApplicationRecord
  validates :user_message, presence: true
  validates :ai_response, presence: true, allow_blank: true

  belongs_to :user, optional: true
end
