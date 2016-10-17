require_relative 'prime_field'
require_relative 'point'

module Ant::ECDSA

  class Group

    attr_reader :name
    attr_reader :generator
    attr_reader :order
    attr_reader :cofactor
    attr_reader :param_a
    attr_reader :param_b
    attr_reader :field

    def initialize(opts)
      @opts = opts

      @name = opts.fetch(:name) { '%#x' % object_id }
      @field = PrimeField.new(opts[:p])
      @param_a = opts[:a]
      @param_b = opts[:b]
      @generator = new_point(@opts[:g])
      @order = opts[:n]
      @cofactor = opts[:h]

      @param_a.is_a?(Integer) or raise ArgumentError, 'Invalid a.'
      @param_b.is_a?(Integer) or raise ArgumentError, 'Invalid b.'

      @param_a = field.mod @param_a
      @param_b = field.mod @param_b
    end

    def new_point(p)
      case p
      when :infinity
        infinity
      when Array
        x, y = p
        Point.new(self, x, y)
      when Integer
        generator.multiply_by_scalar(p)
      else
        raise ArgumentError, "Invalid point specifier #{p.inspect}."
      end
    end

    def infinity
      @infinity ||= Point.new(self, :infinity)
    end

    def bit_length
      @bit_length ||= Ant::ECDSA.bit_length(field.prime)
    end

    def byte_length
      @byte_length ||= Ant::ECDSA.byte_length(field.prime)
    end

    def include?(point)
      return false if point.group != self
      point.infinity? or point_satisfies_equation?(point)
    end

    def valid_public_key?(point)
      return false if point.group != self
      return false if point.infinity?
      return false if !point_satisfies_equation?(point)
      point.multiply_by_scalar(order).infinity?
    end

    def partially_valid_public_key?(point)
      return false if point.group != self
      return false if point.infinity?
      point_satisfies_equation?(point)
    end

    def solve_for_y(x)
      field.square_roots equation_right_hand_side x
    end

    def inspect
      "#<#{self.class}:#{name}>"
    end

    def to_s
      inspect
    end

    private

    def point_satisfies_equation?(point)
      field.square(point.y) == equation_right_hand_side(point.x)
    end

    def equation_right_hand_side(x)
      field.mod(x * x * x + param_a * x + param_b)
    end

    NAMES = %w(
      Nistp192
      Nistp224
      Nistp256
      Nistp384
      Nistp521
      Secp112r1
      Secp112r2
      Secp128r1
      Secp128r2
      Secp160k1
      Secp160r1
      Secp160r2
      Secp192k1
      Secp192r1
      Secp224k1
      Secp224r1
      Secp256k1
      Secp256r1
      Secp384r1
      Secp521r1
    )

    NAMES.each do |name|
      autoload name, 'ant/ecdsa/group/' + name.downcase
    end

    alias_method :infinity_point, :infinity
  end
end
