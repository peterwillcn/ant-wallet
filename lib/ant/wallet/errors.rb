module Ant::Wallet
	class Error < StandardError
		def self.status_code(code)
      define_method(:status_code) { code }
      if match = Error.all_errors.find {|_k, v| v == code }
        error, _ = match
        raise ArgumentError,
          "Trying to register #{self} for status code #{code} but #{error} is already registered"
      end
      Error.all_errors[self] = code
    end

    def self.all_errors
      @all_errors ||= {}
    end
  end

  class PermissionError < Error
    def initialize(path, permission_type = :write)
      @path = path
      @permission_type = permission_type
    end

    def action
      case @permission_type
      when :read then "read from"
      when :write then "write to"
      when :executable, :exec then "execute"
      else @permission_type.to_s
      end
    end

    def message
      "There was an error while trying to #{action} `#{@path}`. " \
      "It is likely that you need to grant #{@permission_type} permissions " \
      "for that path."
    end

    status_code(23)
  end

  class TemporaryResourceError < PermissionError
    def message
      "There was an error while trying to #{action} `#{@path}`. " \
      "Some resource was temporarily unavailable. It's suggested that you try" \
      "the operation again."
    end

    status_code(26)
  end

  class VirtualProtocolError < Error
    def message
      "There was an error relating to virtualization and file access." \
      "It is likely that you need to grant access to or mount some file system correctly."
    end

    status_code(27)
  end

  class OperationNotSupportedError < PermissionError
    def message
      "Attempting to #{action} `#{@path}` is unsupported by your OS."
    end

    status_code(28)
  end

end