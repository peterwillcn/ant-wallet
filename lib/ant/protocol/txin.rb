# encoding: ascii-8bit

module Ant
  module Protocol

    class TxIn

      attr_accessor :prev_out_hash, :prev_out_index

      def initialize *args
        @prev_out_hash, @prev_out_index = *args
      end

      # compare to another txin
      def ==(other)
        @prev_out_hash == other.prev_out_hash &&
          @prev_out_index == other.prev_out_index
      rescue
        false
      end

      def to_payload
        [[prev_out_hash].pack("H*").reverse, [prev_out_index].pack("S")].join
      end

    end

  end
end
