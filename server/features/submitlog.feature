# language:en
#
# Author:: N6RNO
#
# License::  &copy; 2014 Northern California Contest Club
#            2-Clause BSD License
#

Feature:
  In order to score a contest A
  As a sponsor
  I want a user to submit a log

  @wip 
  Scenario: Cabrillo 3.0 format log loaded from web
    Given a contest A
    When User submits a log N6RNO.CAB3
    And log is Cabrillo
    And log is version 3.0
    Then save the log
    And accept the log
    
  Scenario: Cabrillo 3.0 format log pasted from web
    Given a contest A
    When User pastes log:
      """
      START-OF-LOG: 3.0
      CALLSIGN: N6RNO
      CLUB: Northern California Contest Club
      CONTEST: A
      CATEGORY-OPERATOR: MULTI-OP
      CATEGORY-TRANSMITTER: UNLIMITED 
      CATEGORY-BAND: ALL 
      CATEGORY-POWER: HIGH 
      CATEGORY-MODE: MIXED
      CLAIMED-SCORE: 315404
      OPERATORS: N3ZZ K9YC K6MI N6RNO NO6X WB6HYD K6VLF 
      NAME: Jim Brown
      ADDRESS: 599 DX Lane
      ADDRESS-CITY: Santa Cruz
      ADDRESS-STATE-PROVINCE: CA
      ADDRESS-POSTAL-CODE: 95060
      ADDRESS-COUNTRY: USA
      CREATED-BY: N1MM Logger V9.9.7
      QSO: 14026 CW 2009-10-03 1605 N6RNO         0001 TEHA  N3UM          0002 MD    
      QSO: 14032 CW 2009-10-03 1608 N6RNO         0002 TEHA  NE8J          0002 FL    
      QSO: 14032 CW 2009-10-03 1609 N6RNO         0003 TEHA  K1IB          0002 VT    
      END-OF-LOG:
      """
    And log is Cabrillo
    And log is version 3.0
    Then save the log
    And accept the log
   
  Scenario: Cabrillo 2.0 format log loaded from web
    Given a contest A
    When User submits a log N6RNO.CAB2
    And log is Cabrillo
    And log is version 2.0
    Then save the log
    And convert log to 3.0 format and save again
    And accept the log
         
  Scenario Outline: non-cabrillo format log loaded from web
    Given a contest A
    When User submits a log <name>
    Then save the log
    And warn User the log is not legal
    And suggest how to correct the log
    And reject the log
    
  Scenarios: bad logs 
    | name | type |
    | N6RNO.adi | :ADIF |
    | ae6rf.xls | :EXCEL |
    | sampele.adx | :ADX |
  
  Scenario: multiple logs for same User
    Given a contest A
    When a log already saved for User
    And User submits a log N6RNO2.CAB3
    Then save the log
    And warn User about overwrite
    
  Scenario: Log not for this contest
    Given a contest A
    When User submits a log N6RNO.CAB3B
    And log is for contest B
    Then save the log
    And warn User log is for wrong contest
    And reject the log
    
  