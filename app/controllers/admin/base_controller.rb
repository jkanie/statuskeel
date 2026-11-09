# Every admin screen needs a signed-in user (the Authentication concern requires it by default).
class Admin::BaseController < ApplicationController
  # The admin screens use import maps and Trix, so old browsers get the 406 page. The public page has no such limit.
  allow_browser versions: :modern

  layout "admin"
end
