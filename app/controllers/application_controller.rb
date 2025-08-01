class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  before_action :configure_permitted_parameters, if: :devise_controller?
  include Pundit::Authorization
  protect_from_forgery with: :exception

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from StandardError, with: :handle_standard_error unless Rails.env.development? || Rails.env.test?

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end

  def handle_standard_error(exception)
    logger.error(exception)
    flash[:alert] = "Something went wrong. Please try again."
    redirect_back(fallback_location: root_path)
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :role])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :role])
  end

end
