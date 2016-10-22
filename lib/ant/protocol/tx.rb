# encoding: ascii-8bit
require 'securerandom'
require 'digest/sha2'
require "ant/ecdsa"
require "ant/wallet/script"

module Ant
  module Protocol

    class Tx

      # transaction type
      attr_reader :type, :ver, :in, :out, :private_key, :public_key
      attr_accessor :stack_script, :redeem_script, :script, :payload

      alias :inputs  :in
      alias :outputs :out

      # create tx
      def initialize *args
        @type, @ver, @private_key, @public_key = *args
      end

      # add an input
      def add_in(input); (@in ||= []) << input; end

      # add an output
      def add_out(output); (@out ||= []) << output; end

      def to_playload
        pin, pout, attributes = "", "", []
        @in.each{|input| pin << input.to_payload }
        @out.each{|output| pout << output.to_payload }
        @payload = Ant::Wallet::Util.pack_var_int(type) <<
        Ant::Wallet::Util.pack_var_int(ver) <<
        #Ant::Wallet::Util.pack_var_int(attributes.size) <<
        Ant::Wallet::Util.pack_var_int(@in.size) << pin <<
        Ant::Wallet::Util.pack_var_int(@out.size) << pout
      end

      def signature_hash
        group = Ant::ECDSA::Group::Secp256r1
        payload = Digest::SHA2.digest(@payload)
        signature = nil
        while signature.nil?
          temp_key = 1 + SecureRandom.random_number(group.order - 1)
          signature = Ant::ECDSA.sign(group, @private_key, payload, temp_key)
        end
        if Ant::ECDSA.valid_signature?(@public_key, payload, signature)
          r, s = signature.r, signature.s
          x = [[r.to_s(16)].pack('H*'), [s.to_s(16)].pack('H*')].join
          x.unpack('H*')[0]
        end
      end

      def to_stack_script
        @stack_script = Ant::Wallet::Script::OP_PUSHBYTES64 + signature_hash
      end

      def to_redeem_script
        public_key_hex = Ant::ECDSA::Format::PointOctetString.encode(@public_key, compression: true).unpack('H*')[0]
        @redeem_script = public_key_hex.rjust(68, Ant::Wallet::Script::OP_PUSHBYTES33) + Ant::Wallet::Script::OP_CHECKSIG
      end

      def to_script
        stack_script, redeem_script = to_stack_script, to_redeem_script
        @script = Ant::Wallet::Util.pack_var_int(stack_script.size/2) <<
         [stack_script].pack("H*") <<
         Ant::Wallet::Util.pack_var_int(redeem_script.size/2) <<
         [redeem_script].pack("H*")
      end

      def generate_tx_hex
        to_playload
        to_script
        @payload <<
         Ant::Wallet::Util.pack_var_int(1) << @script
      end

    end
  end
end
