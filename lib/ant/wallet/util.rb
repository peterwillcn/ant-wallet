require "ant/wallet/version"
require "ant/wallet/script"
require "ant/wallet/errors"
require 'digest/sha2'
require 'digest/rmd160'
require 'openssl'
require 'securerandom'

module Ant::Wallet
  module Util

    def self.hash160(hex)
      bytes = [hex].pack("H*")
      Digest::RMD160.hexdigest Digest::SHA256.digest(bytes)
    end

    def self.checksum(hex)
      b = [hex].pack("H*")
      Digest::SHA256.hexdigest( Digest::SHA256.digest(b) )[0...8]
    end

    def self.int_to_base58(int_val, leading_zero_bytes=0)
      alpha = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
      base58_val, base = '', alpha.size
      while int_val > 0
        int_val, remainder = int_val.divmod(base)
        base58_val = alpha[remainder] + base58_val
      end
      base58_val
    end

    def self.base58_to_int(base58_val)
      alpha = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
      int_val, base = 0, alpha.size
      base58_val.reverse.each_char.with_index do |char,index|
        raise ArgumentError, 'Value not a valid Base58 String.' unless char_index = alpha.index(char)
        int_val += char_index*(base**index)
      end
      int_val
    end

    def self.encode_base58(hex)
      leading_zero_bytes  = (hex.match(/^([0]+)/) ? $1 : '').size / 2
      ("1"*leading_zero_bytes) + int_to_base58( hex.to_i(16) )
    end

    def self.decode_base58(base58_val)
      s = base58_to_int(base58_val).to_s(16); s = (s.bytesize.odd? ? '0'+s : s)
      s = '' if s == '00'
      leading_zero_bytes = (base58_val.match(/^([1]+)/) ? $1 : '').size
      s = ("00"*leading_zero_bytes) + s  if leading_zero_bytes > 0
      s
    end

    def self.encode_script(hex)
      hash160(hex.rjust(68, Ant::Wallet::Script::OP_PUSHBYTES33) + Ant::Wallet::Script::OP_CHECKSIG)
    end

    def self.encode_address(hex, version)
      hex = version + hex
      encode_base58(hex + checksum(hex))
    end

    def self.pubkey_to_address(pubkey)
      encode_address( encode_script(pubkey), Ant::Wallet::Script::OP_VERSION)
    end

    def self.hash160_from_address(address)
      decode_base58(address)[2...42]
    end

    def self.unpack_var_int(payload)
      case payload.unpack("C")[0] # TODO add test cases
      when 0xfd; payload.unpack("xva*")
      when 0xfe; payload.unpack("xVa*")
      when 0xff; payload.unpack("xQa*") # TODO add little-endian version of Q
      else;      payload.unpack("Ca*")
      end
    end

    def self.pack_var_int(i)
      if    i <  0xfd;                [      i].pack("C")
      elsif i <= 0xffff;              [0xfd, i].pack("Cv")
      elsif i <= 0xffffffff;          [0xfe, i].pack("CV")
      elsif i <= 0xffffffffffffffff;  [0xff, i].pack("CQ")
      else raise "int(#{i}) too large!"
      end
    end

    def self.unpack_var_string(payload)
      size, payload = unpack_var_int(payload)
      size > 0 ? (string, payload = payload.unpack("a#{size}a*")) : [nil, payload]
    end

    def self.pack_var_string(payload)
      pack_var_int(payload.bytesize) + payload
    end

    def self.unpack_boolean(payload)
      bdata, payload = payload.unpack("Ca*")
      [ (bdata == 0 ? false : true), payload ]
    end

    def self.pack_boolean(b)
      (b == true) ? [0xFF].pack("C") : [0x00].pack("C")
    end

    def self.to_bip38(passphrase, privkey, addr)
      addresshash = Digest::SHA256.digest( Digest::SHA256.digest( addr ) )[0...4]
      require 'scrypt' unless defined?(::SCrypt::Engine)
      buf = SCrypt::Engine.__sc_crypt(passphrase, addresshash, 16384, 8, 8, 64)
      derivedhalf1, derivedhalf2 = buf[0...32], buf[32..-1]

      aes = proc{|k,a,b|
        cipher = OpenSSL::Cipher::AES.new(256, :ECB); cipher.encrypt; cipher.padding = 0; cipher.key = k
        cipher.update [ (a.to_i(16) ^ b.unpack("H*")[0].to_i(16)).to_s(16).rjust(32, '0') ].pack("H*")
      }

      encryptedhalf1 = aes.call(derivedhalf2, privkey[0...32], derivedhalf1[0...16])
      encryptedhalf2 = aes.call(derivedhalf2, privkey[32..-1], derivedhalf1[16..-1])

      encrypted_privkey = addresshash + encryptedhalf1 + encryptedhalf2
      encrypted_privkey += Digest::SHA256.digest( Digest::SHA256.digest( encrypted_privkey ) )[0...4]

      encrypted_privkey = encode_base58( encrypted_privkey.unpack("H*")[0] )
    end

    def self.from_bip38(encrypted_privkey, passphrase, addr)
      addresshash, encryptedhalf1, encryptedhalf2, checksum =
        [ decode_base58(encrypted_privkey) ].pack("H*").unpack("a4a16a16a4")
      raise "Invalid checksum"  unless Digest::SHA256.digest(Digest::SHA256.digest(addresshash + encryptedhalf1 + encryptedhalf2))[0...4] == checksum
      require 'scrypt' unless defined?(::SCrypt::Engine)
      buf = SCrypt::Engine.__sc_crypt(passphrase, addresshash, 16384, 8, 8, 64)
      derivedhalf1, derivedhalf2 = buf[0...32], buf[32..-1]

      aes = proc{|k,a|
        cipher = OpenSSL::Cipher::AES.new(256, :ECB); cipher.decrypt; cipher.padding = 0; cipher.key = k
        cipher.update(a)
      }

      decryptedhalf2 = aes.call(derivedhalf2, encryptedhalf2)
      decryptedhalf1 = aes.call(derivedhalf2, encryptedhalf1)

      privkey = decryptedhalf1 + decryptedhalf2
      privkey = (privkey.unpack("H*")[0].to_i(16) ^ derivedhalf1.unpack("H*")[0].to_i(16)).to_s(16).rjust(64, '0')

      pubkey = generate_point privkey.to_i(16)

      if Digest::SHA256.digest( Digest::SHA256.digest( addr ) )[0...4] != addresshash
        raise "Invalid addresshash! Password is likely incorrect."
      end

      [privkey, pubkey]
    end

    def self.generate_point priv_bignum
      group = Ant::ECDSA::Group::Secp256r1
      # priv_bignum = 1 + SecureRandom.random_number(group.order - 1) unless priv_bignum
      pubkey_xy_point_bignum = group.generator.multiply_by_scalar(priv_bignum)
    end

  end
end
