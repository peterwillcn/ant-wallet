require 'openssl'
require 'base64'

module Ant::Wallet
  class << self
    def encrypt(plain_text, key, opts={})
      AES.new(key, opts).encrypt(plain_text)
    end

    def decrypt(cipher_text, key, opts={})
      AES.new(key, opts).decrypt(cipher_text)
    end

    def key(length=256,format=:plain)
      key = AES.new("").random_key(length)
      case format
      when :base_64
        Base64.encode64(key).chomp
      else
        key
      end
    end
    
    def iv(format=:plain)
      iv = AES.new("").random_iv
      case format
      when :base_64
        Base64.encode64(iv).chomp
      else
        iv
      end      
    end
  end
  
  class AES
    attr :options
    attr :key
    attr :iv
    attr :cipher
    attr :cipher_text
    attr :plain_text
  
    def initialize(key, opts={})
      merge_options opts
      @cipher = nil
      @key    = key
      @iv   ||= random_iv
      self
    end
  
    def encrypt(plain_text)
      @plain_text = plain_text
      _setup(:encrypt)
      @cipher.iv  = @iv
      case @options[:format]
      when :base_64
        @cipher_text = b64_e(@iv) << "$" << b64_e(_encrypt)
      else
        @cipher_text = [@iv, _encrypt]
      end
      @cipher_text
    end
 
    def decrypt(cipher_text)
      @cipher_text = cipher_text
      _setup(:decrypt)
      case @options[:format]
      when :base_64
        ctext = b64_d(@cipher_text)
      else
        ctext = @cipher_text
      end
      @cipher.iv  = ctext[0]
      @plain_text = @cipher.update(ctext[1]) + @cipher.final 
    end

    def random_iv
      _setup(:encrypt)
      @cipher.random_iv
    end
  
    def random_key(length=256)
      _random_seed.unpack('H*')[0][0..((length/8)-1)]
    end
  
    private
    
      def _random_seed(size=32)
        if defined? OpenSSL::Random
          return OpenSSL::Random.random_bytes(size)
        else
          chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
          (1..size).collect{|a| chars[rand(chars.size)] }.join        
        end
      end
    
      def b64_d(data)
        iv_and_ctext = []
        data.split('$').each do |part|
          iv_and_ctext << Base64.decode64(part)
        end
        iv_and_ctext
      end
  
      def b64_e(data)
        Base64.encode64(data).chomp
      end
  
      def _encrypt
        @cipher.update(@plain_text) + @cipher.final
      end

      def merge_options(opts)
        @options = {
          :format  => :base_64,
          :cipher  => "AES-256-CBC",
          :iv      => nil,
          :padding => true,
        }.merge! opts
        _handle_iv
        _handle_padding
      end
      
      def _handle_iv
        @iv = @options[:iv]
        return if @iv.nil?

        case @options[:format]
        when :base_64
          @iv  = Base64.decode64(@options[:iv])
        end
      end
      
      def _handle_padding
        @options[:padding] = @options[:padding] ? 1 : 0
      end
      
      def _setup(action)
        @cipher ||= OpenSSL::Cipher::Cipher.new(@options[:cipher]) 
        # Toggles encryption mode
        @cipher.send(action)
        @cipher.padding = @options[:padding]
        @cipher.key = @key.unpack('a2'*32).map{|x| x.hex}.pack('c'*32)
      end
  end
end
