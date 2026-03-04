module Admin
  class BaseController < ApplicationController
    http_basic_authenticate_with(
      name:     ENV.fetch("ADMIN_USERNAME", "admin"),
      password: ENV.fetch("ADMIN_PASSWORD", "changeme")
    )

    layout "admin"
  end
end
