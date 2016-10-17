module Ant::ECDSA
  module Format
    module FieldElementOctetString
      def self.encode(element, field)
        raise ArgumentError, 'Given element is not an element of the field.' if !field.include?(element)
        length = Ant::ECDSA.byte_length(field.prime)
        IntegerOctetString.encode(element, length)
      end

      def self.decode(string, field)
        int = IntegerOctetString.decode(string)

        if !field.include?(int)
          raise DecodeError, 'Decoded integer is too large for field: 0x%x >= 0x%x.' % [int, field.prime]
        end

        int
      end
    end
  end
end
