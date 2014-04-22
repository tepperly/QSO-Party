# language:en
#
# Author:: N6RNO
#
# License::  &copy; 2014 Northern California Contest Club
#            2-Clause BSD License
#

Feature:
  In order to score a contest
  As a sponsor
  I want a user to submit a log

    
  Scenario: Cabrillo 3.0 format log loaded from web
    Given a log in format cabrillo
    When User submits good log
    And log is version 3.0
    Then save the log
    And accept the log
   
  Scenario: Cabrillo 2.0 format log loaded from web
    Given a log in format cabrillo
    When User submits good log
    And log is version 2.0
    Then save the log
    And convert log to 3.0 format and save again
    And accept the log
         
  Scenario Outline: non-cabrillo format log loaded from web
    Given a log in format <type>
    When User submits bad format log <name>
    Then save the log
    And warn User the log is not legal
    And suggest how to correct the log
    And reject the log
    
  Scenarios: bad logs 
    | name | type |
    | adif.log | adif |
    | excel.xls | excel |
    | summary.tx | text |
  
  Scenario: multiple logs for same User
    Given a log already saved for User
    When User submits two logs
    Then save the log
    And warn User about overwrite
    
  Scenario: Log not for this contest
    Given a log in format cabrillo
    When User submits wrong contest log
    Then save the log
    And warn User log is for wrong contest
    And reject the log
    
  