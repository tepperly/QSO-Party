# lang:en
# encoding: UTF-8
# Author:: N6RNO
#
# License::  &copy; 2014 Northern California Contest Club
#            2-Clause BSD License
require 'spec_helper'

module Contestlog
  filename = nil
  describe Genericlog do
    let(:log) {Genericlog.new(filename)}
  
    it 'opens nil log' do
      filename = nil
      expect(log.name).to eq(nil)
      expect(log.coding).to eq(:unknown)
      expect(log.files).to eq([])
      expect(log.data).to eq([]) 
    end
    
    it 'opens N6RNO cabrillo 3.0 log' do
      filename = datafile("N6RNO.CAB2")
      expect(log.coding).to eq(:Cabrillo)
      expect(log.name).to eq("N6RNO.CAB2")
      expect(log.files).to eq([])
      expect(log.data[0]).to match(/START-OF-LOG: 2.0\r?\n/) 
    end

    it 'opens N6RNO cabrillo 3.0 log' do
      filename = datafile("N6RNO.CAB3")
      expect(log.coding).to eq(:Cabrillo)
      expect(log.name).to eq("N6RNO.CAB3")
      expect(log.data[0]).to match(/START-OF-LOG: 3.0\r?\n/) 
    end

    it 'opens N6RNO zip log' do
      filename = datafile("N6RNO.zip")
      expect(log.coding).to eq(:ZIP)
      expect(log.name).to eq("N6RNO.zip")
    end
        
    it 'opens VE3HX (ASCII QSO) log' do
      filename = datafile("VE3HX.QSO.LOG")
      expect(log.coding).to eq(:CabrilloQSOonly)
      expect(log.name).to eq("VE3HX.QSO.LOG")
    end

    it 'opens ae6rf Excel 97 log' do
      filename = datafile("ae6rf.xls")
      expect(log.coding).to eq(:EXCEL)
      expect(log.name).to eq("ae6rf.xls")
    end

    it 'opens ae6rf Excel log' do
      filename = datafile("ae6rf.xlsx")
      expect(log.coding).to eq(:EXCEL)
      expect(log.name).to eq("ae6rf.xlsx")
    end

    it 'opens ae6rf Open Office Spreadsheet log' do
      filename = datafile("ae6rf.ods")
      expect(log.coding).to eq(:ODS)
      expect(log.name).to eq("ae6rf.ods")
    end

    it 'opens ae6rf csv log' do
      filename = datafile("ae6rf.csv")
      expect(log.coding).to eq(:CSV)
      expect(log.name).to eq("ae6rf.csv")
    end
        
    it 'opens N6RNO adif log' do
      filename = datafile("N6RNO.ADI")
      expect(log.coding).to eq(:ADIF)
      expect(log.name).to eq("N6RNO.ADI")
    end
    
    it 'opens sample ADX log' do
      filename = datafile("sample.adx")
      expect(log.coding).to eq(:ADX)
      expect(log.name).to eq("sample.adx")
    end    
  end
end
