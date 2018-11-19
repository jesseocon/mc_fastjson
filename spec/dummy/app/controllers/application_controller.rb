class ApplicationController < ActionController::Base
  include McFastjson::FastjsonCompanion
  include ::Pundit
end
