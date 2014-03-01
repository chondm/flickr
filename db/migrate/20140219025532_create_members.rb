class CreateMembers < ActiveRecord::Migration
  def change
    create_table :members do |t|
      t.string :nsid
      t.string :username
      t.string :membertype
      t.text :realname
      t.string :email
      t.string :website
      t.timestamps
    end
  end
end
