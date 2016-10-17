module Ant::ECDSA

  class PrimeField

    attr_reader :prime

    def initialize(prime)
      raise ArgumentError, "Invalid prime #{prime.inspect}" if !prime.is_a?(Integer)
      @prime = prime
    end

    def include?(e)
      e.is_a?(Integer) && e >= 0 && e < prime
    end

    def mod(n)
      n % prime
    end

    def inverse(n)
      raise ArgumentError, '0 has no multiplicative inverse.' if n.zero?

      remainders = [n, prime]
      s = [1, 0]
      t = [0, 1]
      arrays = [remainders, s, t]
      while remainders.last > 0
        quotient = remainders[-2] / remainders[-1]
        arrays.each do |array|
          array << array[-2] - quotient * array[-1]
        end
      end

      raise 'Inversion bug: remainder is not 1.' if remainders[-2] != 1
      mod s[-2]
    end

    def power(n, m)
      result = 1
      v = n
      while m > 0
        result = mod result * v if m.odd?
        v = square v
        m >>= 1
      end
      result
    end

    def square(n)
      mod n * n
    end

    def square_roots(n)
      raise ArgumentError, "Not a member of the field: #{n}." if !include?(n)
      case
      when prime == 2 then [n]
      when (prime % 4) == 3 then square_roots_for_p_3_mod_4(n)
      when (prime % 8) == 5 then square_roots_for_p_5_mod_8(n)
      else square_roots_default(n)
      end
    end

    def self.factor_out_twos(x)
      e = 0
      while x.even?
        x /= 2
        e += 1
      end
      [e, x]
    end

    def self.jacobi(n, p)
      raise 'Jacobi symbol is not defined for primes less than 3.' if p < 3

      n = n % p

      return 0 if n == 0  # Step 1
      return 1 if n == 1  # Step 2

      e, n1 = factor_out_twos n                         # Step 3
      s = (e.even? || [1, 7].include?(p % 8)) ? 1 : -1  # Step 4
      s = -s if (p % 4) == 3 && (n1 % 4) == 3           # Step 5

      # Step 6 and 7
      return s if n1 == 1
      s * jacobi(p, n1)
    end

    private

    def jacobi(n)
      self.class.send(:jacobi, n, prime)
    end

    def square_roots_for_p_3_mod_4(n)
      candidate = power n, (prime + 1) / 4
      square_roots_given_candidate n, candidate
    end

    def square_roots_for_p_5_mod_8(n)
      case power n, (prime - 1) / 4
      when 1
        candidate = power n, (prime + 3) / 8
      when prime - 1
        candidate = mod 2 * n * power(4 * n, (prime - 5) / 8)
      else
        return []
      end
      square_roots_given_candidate n, candidate
    end

    def square_roots_default(n)
      return [0] if n == 0
      return [] if jacobi(n) == -1   # Step 1

      # Step 2
      b = (1...prime).find { |i| jacobi(i) == -1 }

      s, t = self.class.factor_out_twos(prime - 1)  # Step 3
      n_inv = inverse(n)  # Step 4

      # Step 5
      c = power b, t
      r = power n, (t + 1) / 2

      # Step 6
      (1...s).each do |i|
        d = power r * r * n_inv, 1 << (s - i - 1)
        r = mod r * c if d == prime - 1
        c = square c
      end

      square_roots_given_candidate n, r
    end

    def square_roots_given_candidate(n, candidate)
      return [] if square(candidate) != n
      [candidate, mod(-candidate)].uniq.sort
    end
  end
end
