# encoding: utf-8
$stdout.sync = true

require 'yaml'
require 'singleton'
require 'optparse'
require 'fileutils'
require 'erb'

module Ant::Wallet

	class Shutdown < Interrupt; end

	class CLI
		include Singleton unless $TESTING

		def self.banner
			%q{
       _______
      < Good! >
       -------
              \   ^__^
               \  (oo)\_______
                  (__)\       )\/\
                      ||----w |
                      ||     ||
			}
		end

		def parse(args=ARGV)
     print_banner
     setup_options(args)
     initialize_logger
    end

		def run
			daemonize
		end

    def boot
      start
    end

    def halt
      shutdown
    end

private

    def print_banner
      puts "\e[#{31}m"
      puts Ant::Wallet::CLI.banner
      puts "\e[0m"
    end

    def daemonize
      db = Ant::Wallet::Store.new(Ant::Wallet::HOME + 'data.db')
      rows = db.select 'wallets'
      address = []
      rows.each { |row| address << row[4] }
      q = Ant::Wallet::Queue.new address
      q.run
    end

    def start
      ru = ::File.expand_path('../../../../server.ru', __FILE__)
      system "thin -R #{ru} -P /tmp/pids/thin.pid -p 11332 -d start"
    end

    def shutdown
      pid = ::File.expand_path('/tmp/pids/thin.pid', __FILE__)
      system "kill -9 `cat #{pid}`"
    end

    def setup_options(args)
      opts = parse_options(args)

      cfile = Ant::Wallet::File.user_home + '/.wallet/wallet.log'
      opts = parse_config(cfile).merge(opts) if cfile

      options.merge!(opts)
    end

    def options
      Ant::Wallet.options
    end

    def parse_config(cfile)
      opts = {}
      opts[:logfile] = cfile
      if ::File.exist?(cfile)
        opts = YAML.load(ERB.new(IO.read(cfile)).result) || opts
      else
        # allow a non-existent config file so use the defaults.
      end
      opts
    end

    def parse_options(argv)
      opts = {}
      @parser = OptionParser.new do |o|
      	o.on '-i', '--initialize', "Initialize database" do |arg|
          opts[:initialize] = arg
          Ant::Wallet.create_database
        end
        o.on '-n', '--new password, number', Array, "Create encrypted address" do |list|
          opts[:new] = list
          Ant::Wallet.generate_address(opts[:new][0], opts[:new][1].to_i)
        end
        o.on '-l', '--list', "List all address" do |arg|
          opts[:list] = arg
          Ant::Wallet.list_address
        end
        o.on '-f', '--find address', "Find a address" do |arg|
          opts[:address] = arg
          Ant::Wallet.find_address opts[:address]
        end
        o.on '-t', '--transaction', "List all transaction" do |arg|
          opts[:list] = arg
          Ant::Wallet.list_transaction
        end
        o.on '-e', '--raw', "List all raw" do |arg|
          opts[:list] = arg
          Ant::Wallet.list_hex
        end
        o.on '-o', '--send id', "Send raw" do |arg|
          opts[:id] = arg
          Ant::Wallet.send_hex opts[:id]
        end
        o.on '-a', '--all transaction', "Find a transaction" do |arg|
          opts[:address] = arg
          Ant::Wallet.find_transaction_for_address opts[:address]
        end
        o.on '-s', '--sync height', "Sync block data" do |arg|
          opts[:height] = arg
          Ant::Wallet.fix_block_data opts[:height].to_i
        end
        o.on '-g', '--get address', "find a address balance" do |arg|
          opts[:address] = arg
          Ant::Wallet.find_balance_for_address opts[:address]
        end
        o.on '-d', '--daemon', "Daemonize process" do |arg|
          opts[:daemon] = arg
          run
        end
        o.on '-b', '--boot', "Boot rpc process" do |arg|
          opts[:boot] = arg
          boot
        end
        o.on '-x', '--shutdown', "Shutdown rpc process" do |arg|
          opts[:shutdown] = arg
          halt
        end
        o.on "-v", "--verbose", "Print more verbose output" do |arg|
          opts[:verbose] = arg
        end
        o.on '-C', '--config PATH', "path to YAML config file" do |arg|
          opts[:config_file] = arg
        end
        o.on '-L', '--logfile PATH', "path to writable logfile" do |arg|
          opts[:logfile] = arg
        end
        o.on '-V', '--version', "Print version and exit" do |arg|
          puts "AntWallet #{Ant::Wallet::VERSION}"
        end
      end

      @parser.banner = "\n  Usage: wlt [options] [parameter]"
      @parser.on_tail "-h", "--help", "Show help" do
      	#puts @parser
        Ant::Wallet.logger.info @parser
      end
      @parser.parse!(argv)
      opts
    end

    def initialize_logger
      Ant::Wallet::Logs.initialize_logger(options[:logfile]) if options[:logfile]
      Ant::Wallet.logger.level = ::Logger::DEBUG if options[:verbose]
    end

	end
end
