module Ant::ECDSA

  class InvalidSignatureError < StandardError
  end

  def self.valid_signature?(public_key, digest, signature)
    check_signature! public_key, digest, signature
  rescue InvalidSignatureError
    false
  end

  def self.check_signature!(public_key, digest, signature)
    group = public_key.group
    field = group.field

    # Step 1
    raise InvalidSignatureError, 'Invalid signature: r is not in the field.' if !field.include?(signature.r)
    raise InvalidSignatureError, 'Invalid signature: s is not in the field.' if !field.include?(signature.s)
    raise InvalidSignatureError, 'Invalid signature: r is zero.' if signature.r.zero?
    raise InvalidSignatureError, 'Invalid signature: s is zero.' if signature.s.zero?

    # Step 2

    # Step 3
    e = normalize_digest(digest, group.bit_length)

    # Step 4
    point_field = PrimeField.new(group.order)
    s_inverted = point_field.inverse(signature.s)
    u1 = point_field.mod(e * s_inverted)
    u2 = point_field.mod(signature.r * s_inverted)

    # Step 5
    r = group.generator.multiply_by_scalar(u1).add_to_point public_key.multiply_by_scalar(u2)
    raise InvalidSignatureError, 'Invalid signature: r is infinity in step 5.' if r.infinity?

    # Steps 6 and 7
    v = point_field.mod r.x

    # Step 8
    raise InvalidSignatureError, 'Invalid signature: v does not equal r.' if v != signature.r

    true
  end
end
