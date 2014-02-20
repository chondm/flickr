class Member < ActiveRecord::Base
 has_and_belongs_to_many :groups
 attr_accessible :nsid, :username, :membertype, :realname, :email
end
