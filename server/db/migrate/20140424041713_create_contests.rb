class CreateContests < ActiveRecord::Migration
  def change
    create_table :contests do |t|
      t.string :name
      t.string :sponsor
      t.date :start_date
      t.time :start_time
      t.date :end_date
      t.time :end_time
      t.date :due_date
      t.time :due_time

      t.timestamps
    end
  end
end
