class LocalesController < ApplicationController
  def update
    if I18n.available_locales.map(&:to_s).include?(params[:locale])
      session[:locale] = params[:locale]
    end

    redirect_back_or_to root_path, allow_other_host: false, status: :see_other
  end
end
