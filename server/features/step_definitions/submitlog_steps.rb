# langauge:en
# lang:en
# Author:: N6RNO
#
# License::  &copy; 2014 Northern California Contest Club
#            2-Clause BSD License

Given(/^a contest (\S+)$/) do |name|
  @contest = Contest.create!
  @contest.update_attribute(:name, name)
end

When(/^User submits a log\s*(|\S+)$/) do |log|
  visit submitlog_path
  fill_in "UserEmail", :with => "XX0XXX@arrl.net"
  fill_in "File", :with => Rails.root.join("spec", "data", log)
  click_button "Submit"
end

When(/^User pastes a log:/) do |log|
  visit submitlog_path
  fill_in "UserEmail", :with => "XX0XXX@arrl.net"
  fill_in "Text", :with => log
  click_button "Submit"
end

When(/^log is (\S+)$/) do |type|
 pending # check if log of type
end

When(/^log is version (\S+)/) do |version|
  pending # correct version ?
end

Then(/^save the log$/) do
  pending # express the regexp above with the code you wish you had
end

Then(/^warn User the log is not legal$/) do
  pending # express the regexp above with the code you wish you had
end

Then(/^suggest how to correct the log$/) do
  pending # express the regexp above with the code you wish you had
end

Then(/^reject the log$/) do
  pending # express the regexp above with the code you wish you had
end

Then(/^accept the log$/) do 
  pending # express the regexp above with the code you wish you had 
end 

Then(/^convert log to (\S+) format and save again$/) do |version| 
  pending # express the regexp above with the code you wish you had 
end 

Given(/^a log already saved for User$/) do 
  pending # express the regexp above with the code you wish you had 
end 

When(/^User submits two logs$/) do 
  pending # express the regexp above with the code you wish you had 
end 

Then(/^warn User about overwrite$/) do 
  pending # express the regexp above with the code you wish you had 
end 

When(/^User submits the log for another contest$/) do 
  pending # express the regexp above with the code you wish you had 
end 

Then(/^warn User log is for wrong contest$/) do 
  pending # express the regexp above with the code you wish you had 
end 