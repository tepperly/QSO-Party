class Logfile < ActiveRecord::Base
  attr_accessible :email, :file
  mount_uploader :file, LogfileUploader
  
  belongs_to :contest
  validates :contest, presence: true
  validates_associated :contest
  validates :email, :file, presence: true 
  
end
