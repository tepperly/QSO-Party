Notes for QSO-PARTY server developers

Once you have a correct environment (See SETUP later in this file) setup, then you can work with 
this Rails application. 

This application is setup for testing with RSpec and Cucumber.

RSpec is used for detailed unit level tests for critical library functions and for all of the MVC stack.

Cucumber is used for system level tests. These tests are intended to show basic user level features are
working as expected. User level is the contest participant or the contest administrator. Detailed corner
cases should be covered with RSpec for performance. So it is OK to write a feature test that shows that
one Cabrillo 2.0 log can be converted into Cabrillo 3.0 when submitted from the web as a file.
It is also OK to test the same conversion from Cut-N-Paste. Further testing of specific labels should be
relegated to the RSpec tests which can completely by-pass the whole file processing bottleneck for 
efficient direct module interfaces.


Getting Sources and running the tests
--------------------------------------

This is an explanation on how to setup a local repository and getting the first tests
running from the master branch for QSO-PARTY.

These instructions are for a Linux environment. Windows is very slow for running Rails 
applications.

Create a directory for you git repository and move into it. Any name, we'll us git in this example.
This is optional as the clone step creates a new directory. 
   mkdir git
   cd git


Now clone the git repository and move into it

   git clone https://github.com/tepperly/QSO-Party.git
   cd QSO-PARTY


The server environment is in the "server" directory. 
   cd server

Now run bundler to make sure you have all the needed Ruby GEMS
   bundle install

Todo: create a "STABLE" branch or tag so that following tests can have an expected result.

Run Rspec tests
   rspec

Run Cucumber tests
   cucumber

Note: level of pass/failure for the two sets of tests may vary.


SETUP
In order to do development work, you will need the following applications available in
your environment. (Currently, this is the list that N6RNO had to add to Debian 7)

git 1.9 or later (N6RNO built version 2.0.0.rc0.38.g1697bf3 from sources)
Ruby 1.9.1 or later (untested with Ruby 2.x)
Rails 3.2 or later (Not Rails 4.X)
Bundler 1.1.4
RSpec 2.14.8
Cucumber 1.3.14
SQLite3 3.7.13
NodeJS 0.10.26 (Built from sources - no Debian package)

Optional: Eclipse + Aptana Studio 3

once you have all of this installed you can start development



