module Ant
  module ECDSA

    def self.recover_public_key(group, digest, signature)
      return enum_for(:recover_public_key, group, digest, signature) if !block_given?

      digest = normalize_digest(digest, group.bit_length)

      each_possible_temporary_public_key(group, digest, signature) do |point|
        yield calculate_public_key(group, digest, signature, point)
      end

      nil
    end

    private

    def self.each_possible_temporary_public_key(group, digest, signature)

      signature.r.step(group.field.prime - 1, group.order) do |x|
        group.solve_for_y(x).each do |y|
          point = group.new_point [x, y]
          yield point if point.multiply_by_scalar(group.order).infinity?
        end
      end
    end

    def self.calculate_public_key(group, digest, signature, temporary_public_key)
      point_field = PrimeField.new(group.order)

      # public key = (tempPubKey * s - G * e) / r
      rs = temporary_public_key.multiply_by_scalar(signature.s)
      ge = group.generator.multiply_by_scalar(digest)
      r_inv = point_field.inverse(signature.r)

      rs.add_to_point(ge.negate).multiply_by_scalar(r_inv)
    end
  end
end
