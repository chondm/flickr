class GroupsMember < ActiveRecord::Base
  validates :group_id, :uniqueness => {:scope => :member_id}
end
