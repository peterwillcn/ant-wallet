require "fileutils"
require "pathname"

module Ant::Wallet
  module File
	  def self.user_home # rubocop:disable MethodLength
	    @@user_home ||= if ENV["HOME"]
	      ENV["HOME"]
	    elsif ENV["USERPROFILE"]
	      ENV["USERPROFILE"]
	    elsif ENV["HOMEDRIVE"] && ENV["HOMEPATH"]
	      File.join(ENV["HOMEDRIVE"], ENV["HOMEPATH"])
	    elsif ENV["APPDATA"]
	      ENV["APPDATA"]
	    else
	      begin
	        File.expand_path("~")
	      rescue
	        if File::ALT_SEPARATOR
	          "C:/"
	        else
	          "/"
	        end
	      end
	    end
	  end

	  def self.filesystem_access(path, action = :write)
	    yield path.dup.untaint
	  rescue Errno::EACCES
	    raise PermissionError.new(path, action)
	  rescue Errno::EAGAIN
	    raise TemporaryResourceError.new(path, action)
	  rescue Errno::EPROTO
	    raise VirtualProtocolError.new
	  rescue *[const_get_safely(:ENOTSUP, Errno)].compact
	    raise OperationNotSupportedError.new(path, action)
	  end  	
  end
end