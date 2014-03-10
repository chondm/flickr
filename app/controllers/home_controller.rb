class HomeController < ApplicationController
  def index
    @total_members = Member.count
    @current_group = Member.last.groups.last
    @total_groups = Group.count
    @emails = Member.where("email is not null").count
  end
end
