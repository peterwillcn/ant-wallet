module Ant
  module ECDSA

    def self.sign(group, private_key, digest, temporary_key)

      r_point = group.new_point temporary_key

      # Steps 2 and 3
      point_field = PrimeField.new(group.order)
      r = point_field.mod(r_point.x)
      return nil if r.zero?

      # Step 4

      # Step 5
      e = normalize_digest(digest, group.bit_length)

      # Step 6
      s = point_field.mod(point_field.inverse(temporary_key) * (e + r * private_key))
      return nil if s.zero?

      Signature.new r, s
    end
  end
end
