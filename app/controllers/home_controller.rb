class HomeController < ApplicationController
  def index
    @total_members = Member.count
    @current_group = Member.last.groups.last
    @total_groups = Group.count
  end
end
