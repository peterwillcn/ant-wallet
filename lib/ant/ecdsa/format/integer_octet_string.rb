module Ant::ECDSA
  module Format

    module IntegerOctetString

      def self.encode(integer, length)
        raise ArgumentError, 'Integer to encode is negative.' if integer < 0
        raise ArgumentError, 'Integer to encode is too large.' if integer >= (1 << (8 * length))

        (length - 1).downto(0).map do |i|
          (integer >> (8 * i)) & 0xFF
        end.pack('C*')
      end

      def self.decode(string)
        string.bytes.reduce { |n, b| (n << 8) + b }
      end
    end
  end
end
