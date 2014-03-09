class Member < ActiveRecord::Base
  has_and_belongs_to_many :groups
  validates :nsid, :uniqueness => true
end
