# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  def create
    super do |user|
      if user.persisted? # Only enqueue the job if the user was successfully saved
        UserMailerJob.perform_later(user.id)
      end
    end
  end
end
