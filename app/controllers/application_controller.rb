class ApplicationController < ActionController::Base
  AWS.config({
    :access_key_id => Settings.access_key_id,
    :secret_access_key => Settings.secret_access_key,
  })

  include Pundit
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  helper_method :nat_instance

  private

  def nat_instance(nat_instance = nil)
    @nat_instance ||= nat_instance
  end

  def user_not_authorized
    flash[:alert] = "Access denied."
    redirect_to (request.referrer || root_path)
  end

end
