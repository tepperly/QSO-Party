# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20140424052637) do

  create_table "contests", :force => true do |t|
    t.string   "name"
    t.string   "sponsor"
    t.date     "start_date"
    t.time     "start_time"
    t.date     "end_date"
    t.time     "end_time"
    t.date     "due_date"
    t.time     "due_time"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "logfiles", :force => true do |t|
    t.integer  "contest_id"
    t.string   "file"
    t.string   "email"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "logfiles", ["contest_id"], :name => "index_logfiles_on_contest_id"

end
