class Contest < ActiveRecord::Base
  attr_accessible :due_date, :due_time, :end_date, :end_time, :name, :sponsor, :start_date, :start_time
end
