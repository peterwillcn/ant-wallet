require 'time'
require 'logger'

module Ant::Wallet
  module Logs
    class Pretty < Logger::Formatter
      SPACE = " "

      def call(severity, time, program_name, message)
        "#{time.utc.iso8601(3)} #{::Process.pid} TID-#{Thread.current.object_id.to_s(36)}#{context} #{severity}: #{message}\n"
      end
      def context
        c = Thread.current[:wallet_context]
        " #{c.join(SPACE)}" if c && c.any?
      end
    end

    class WithoutTimestamp < Pretty
      def call(severity, time, program_name, message)
        "#{::Process.pid} TID-#{Thread.current.object_id.to_s(36)}#{context} #{severity}: #{message}\n"
      end
      def self.with_context(msg)
        Thread.current[:wallet_context] ||= []
        Thread.current[:wallet_context] << msg
        yield
      ensure
        Thread.current[:wallet_context].pop
      end
    end

    def self.initialize_logger(log_target = STDOUT)
      oldlogger = defined?(@logger) ? @logger : nil
      @logger = Logger.new(log_target)
      @logger.level = Logger::INFO
      @logger.formatter = ENV['DYNO'] ? WithoutTimestamp.new : Pretty.new
      oldlogger.close if oldlogger && !$TESTING # don't want to close testing's STDOUT logging
      @logger
    end

    def self.logger
      defined?(@logger) ? @logger : initialize_logger
    end

    def self.logger=(log)
      @logger = (log ? log : Logger.new(File::NULL))
    end

    def logger
      Ant::Wallet::Logs.logger
    end

  end
end
