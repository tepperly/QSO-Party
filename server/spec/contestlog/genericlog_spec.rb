# lang:en
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
      expect(log.name).to eq(nil)
      expect(log.coding).to eq(:unknown)
      expect(log.files).to eq([])
      expect(log.data).to eq([]) 
    end
    
    it 'opens N6RNO cabrillo log' do
      filename = Rails.root.join("spec", "data", "N6RNO.CAB2")
      expect(log.coding).to eq(:Cabrillo)
      expect(log.name).to eq("N6RNO.CAB2")
      expect(log.files).to eq([])
      expect(log.data[0]).to eq("START-OF-LOG: 2.0\r\n") 
    end
  end
end