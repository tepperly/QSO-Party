class CreateLogfiles < ActiveRecord::Migration
  def change
    create_table :logfiles do |t|
      t.references :contest
      t.string :file
      t.string :email

      t.timestamps
    end
    add_index :logfiles, :contest_id
  end
end
