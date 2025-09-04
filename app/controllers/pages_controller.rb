class PagesController < ApplicationController
  before_action :authenticate_user!, except: [ :about, :contact ]

  def about
    @page_title = "About Pirate on Rails"
  end

  def contact
    @page_title = "Contact Us"
  end
end
