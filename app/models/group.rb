class Group < ActiveRecord::Base
  has_and_belongs_to_many :members
  validates :nsid, :uniqueness => true
end
