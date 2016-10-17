module Ant::ECDSA

  class Point

    attr_reader :group
    attr_reader :x
    attr_reader :y

    def initialize(group, *args)
      @group = group

      if args == [:infinity]
        @infinity = true
        # leave @x and @y nil
      else
        x, y = args
        raise ArgumentError, "Invalid x: #{x.inspect}" if !x.is_a? Integer
        raise ArgumentError, "Invalid y: #{y.inspect}" if !y.is_a? Integer

        @x = x
        @y = y
      end
    end

    def coords
      [x, y]
    end

    def add_to_point(other)
      check_group! other

      # Rules 1 and 2
      return other if infinity?
      return self if other.infinity?

      # Rule 3
      return group.infinity if x == other.x && y == field.mod(-other.y)

      # Rule 4
      if x != other.x
        gamma = field.mod((other.y - y) * field.inverse(other.x - x))
        sum_x = field.mod(gamma * gamma - x - other.x)
        sum_y = field.mod(gamma * (x - sum_x) - y)
        return self.class.new(group, sum_x, sum_y)
      end

      # Rule 5
      return double if self == other

      raise "Failed to add #{inspect} to #{other.inspect}: No addition rules matched."
    end
    alias_method :+, :add_to_point

    def negate
      return self if infinity?
      self.class.new(group, x, field.mod(-y))
    end

    # Rule 5.
    def double
      return self if infinity?
      gamma = field.mod((3 * x * x + @group.param_a) * field.inverse(2 * y))
      new_x = field.mod(gamma * gamma - 2 * x)
      new_y = field.mod(gamma * (x - new_x) - y)
      self.class.new(group, new_x, new_y)
    end

    def multiply_by_scalar(i)
      raise ArgumentError, 'Scalar is not an integer.' if !i.is_a?(Integer)
      raise ArgumentError, 'Scalar is negative.' if i < 0
      result = group.infinity
      v = self
      while i > 0
        result = result.add_to_point(v) if i.odd?
        v = v.double
        i >>= 1
      end
      result
    end
    alias_method :*, :multiply_by_scalar

    def eql?(other)
      return false if !other.is_a?(Point) || other.group != group
      x == other.x && y == other.y
    end

    def ==(other)
      eql?(other)
    end

    def hash
      [group, x, y].hash
    end

    def infinity?
      @infinity == true
    end

    def inspect
      if infinity?
        '#<%s: %s, infinity>' % [self.class, group.name]
      else
        '#<%s: %s, 0x%x, 0x%x>' % [self.class, group.name, x, y]
      end
    end

    private

    def check_group!(point)
      raise 'Mismatched groups.' if point.group != group
    end

    def field
      group.field
    end
  end
end
