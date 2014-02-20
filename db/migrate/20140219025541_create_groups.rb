class CreateGroups < ActiveRecord::Migration
  def change
    create_table :groups do |t|
      t.string :nsid
      t.string :name
      t.integer :total_members
      t.timestamps
    end
  end
end
