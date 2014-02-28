class CreateGroupsMembers < ActiveRecord::Migration
  def change
    create_table :groups_members do |t|
      t.belongs_to :group
      t.belongs_to :member
    end
  end
end
