# encoding: ascii-8bit
require 'ant/wallet/util'

module Ant
  module Protocol

    class TxOut

      attr_accessor :asset_id, :value, :address_hash

      def initialize *args
        @asset_id, @value, @address_hash = *args
      end

      # compare to another txout
      def ==(other)
        @asset_id == other.asset_id && @value == other.value &&
         @address_hash == other.address_hash
      rescue
        false
      end

      def to_payload
        [[asset_id].pack("H*").reverse, [value*10**8].pack("Q"), [address_hash].pack("H*")].join
      end

      alias :amount   :value
      alias :amount=  :value=

    end

  end
end
