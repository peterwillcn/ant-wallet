require "ant/wallet/version"
require 'ant/wallet/util'
require 'ant/wallet/logs'
require 'ant/wallet/store'
require 'ant/wallet/files'
require 'ant/wallet/queue'
require 'ant/wallet/errors'
require 'ant/wallet/trx'
require 'ant/protocol/tx'
require 'ant/protocol/txin'
require 'ant/protocol/txout'
require 'jsonrpc/client'
require 'highline/import'

module Ant
  module Wallet

    NAME = 'AntSharesWallet'
    LICENSE = 'See LICENSE and the MIT for licensing details.'

    #http://124.42.118.215:10332
    #c56f33fc6ecfcd0c225c4ab356fee59390af8560be0e930faebe74a6daff7c9b

    #http://123.206.53.170:20332
    #dc3d9da12d13a4866ced58f9b611ad0d1e9d5d2b5b1d53021ea55a37d3afb4c9

    DEFAULTS = {
      home: Ant::Wallet::File.user_home + '/.wallet/',
      addr: 'ATtsWQwLDpk1ecHiqwkxs7oNy9th6LDXhF',
      node: 'http://124.42.118.215:10332',
      type: 'c56f33fc6ecfcd0c225c4ab356fee59390af8560be0e930faebe74a6daff7c9b' #ANS
    }

    HOME = DEFAULTS[:home]
    ADDR = DEFAULTS[:addr]
    TYPE = DEFAULTS[:type]
    BCHOST = DEFAULTS[:node]

    DDL_WALLETS = 'create table IF NOT EXISTS wallets
      ( id integer PRIMARY KEY AUTOINCREMENT, name varchar(30), encrypted_privkey varchar(128),
        public_key_hex varchar(128), address varchar(64), state integer, coin varchar(30),
        balance NUMERIC default 0.0, UNIQUE(encrypted_privkey) ON CONFLICT REPLACE
      );'

    DDL_TXOUTS = 'create table IF NOT EXISTS txouts
    ( id integer PRIMARY KEY AUTOINCREMENT, address varchar(64), height integer, prev_tx_output_hash varchar(64),
      prev_tx_output_index integer, asset_id varchar(64), balance NUMERIC default 0.0, state varchar(4) default "Y",
      UNIQUE(prev_tx_output_hash, prev_tx_output_index) ON CONFLICT REPLACE
    );'

    DDL_RAWS = 'create table IF NOT EXISTS raws
    ( id integer PRIMARY KEY AUTOINCREMENT, address varchar(64), amount NUMERIC default 0.0,
      hex text, asset_id varchar(64), height integer, state varchar(4) default "N"
    );'

    #ddl = 'alter table wallets add column balance NUMERIC default 0.0;'

    def self.create_database
      begin
        Ant::Wallet::File.filesystem_access(HOME, :write) do |p|
          FileUtils.mkdir_p(p)
        end
      rescue => e
        warning = "\n\n also failed to create a temporary home directory at `#{HOME}`:\n#{e}"
        raise warning
      end

      db = Ant::Wallet::Store.new(HOME + 'data.db')
      db.create_table DDL_WALLETS
      db.create_table DDL_TXOUTS

      db = Ant::Wallet::Store.new(HOME + 'raw.db')
      db.create_table DDL_RAWS

      db.close
    end

    def self.generate_address(passwd, number)
      group = Ant::ECDSA::Group::Secp256r1
      db = Ant::Wallet::Store.new (HOME + 'data.db')
      number.times do
        encrypted_privkey, public_key_hex, address = generate(passwd)
        dml = { name: 'yunbi', encrypted_privkey: encrypted_privkey,
          public_key_hex: public_key_hex, address: address, state: 1,  coin: 'antcoin'}
        Ant::Wallet.logger.info dml
        db.insert('wallets', dml)
      end
      db.close
    end

    def self.list_address
      db = Ant::Wallet::Store.new(HOME + 'data.db')
      rows = db.select 'wallets'
      db.close
      Ant::Wallet.logger.info rows
    end

    def self.list_transaction
      db = Ant::Wallet::Store.new(HOME + 'data.db')
      rows = db.select 'txouts'
      db.close
      Ant::Wallet.logger.info rows
    end

    def self.list_hex
      db = Ant::Wallet::Store.new(HOME + 'raw.db')
      rows = db.select 'raws'
      db.close
      Ant::Wallet.logger.info rows
    end

    def self.send_hex id
      client = JSONRPC::Client.new BCHOST
      db = Ant::Wallet::Store.new(HOME + 'raw.db')
      row = db.find_hex 'raws', id
      hex = row[0][3]
      Ant::Wallet.logger.info hex
      status = client.sendrawtransaction hex
      Ant::Wallet.logger.info status
    end

    def self.find_address address
      db = Ant::Wallet::Store.new(HOME + 'data.db')
      row = db.find 'wallets', address
      db.close
      Ant::Wallet.logger.info row
    end

    def self.find_transaction_for_address address
      db = Ant::Wallet::Store.new(HOME + 'data.db')
      row = db.find_tx 'txouts', address
      db.close
      Ant::Wallet.logger.info row
    end

    def self.fix_block_data height
      db = Ant::Wallet::Store.new(HOME + 'data.db')
      rows = db.select 'wallets'
      address = []
      rows.each { |row| address << row[4] }
      q = Ant::Wallet::Queue.new address
      db.close
      Ant::Wallet.logger.info q.fix_data height
    end

    def self.find_balance_for_address address=nil
      db = Ant::Wallet::Store.new(HOME + 'data.db')
      balance = 0
      if address
        txin = db.find_tx 'txouts', address
        txin.each do |tx|
          balance += tx[6]
        end
      else
        txin = db.find_all_tx 'txouts'
        txin.each do |tx|
          balance += tx[6]
        end
      end
      Ant::Wallet.logger.info balance
      db.close
      balance
    end

    def self.keygen
      number = ask("Enter number address:  ") { |q| q.echo = true }
      passwd1 = ask("Enter your password:  ") { |q| q.echo = "*" }
      passwd2 = ask("Enter again your password:  ") { |q| q.echo = "*" }
      if passwd1 == passwd2
        db = Ant::Wallet::Store.new(HOME + 'data.db')
          number.to_i.times do
            keys = generate(passwd2)
            if keys.all?
              encrypted_privkey, public_key_hex, address = keys
              dml = { name: 'yunbi', encrypted_privkey: encrypted_privkey,
                public_key_hex: public_key_hex, address: address, state: 1,  coin: 'ans'}
              Ant::Wallet.logger.info dml
              db.insert('wallets', dml)
            end
          end
        db.close
      end
    end

    def self.options
      @options ||= DEFAULTS.dup
    end
    def self.options=(opts)
      @options = opts
    end

    def self.logger
      Ant::Wallet::Logs.logger
    end

    def self.logger=(log)
      Ant::Wallet::Logs.logger = log
    end

    def self.generate passwd
      keys = []
      group = Ant::ECDSA::Group::Secp256r1
      private_key = 1 + SecureRandom.random_number(group.order - 1)
      private_key_hex = private_key.to_s(16).rjust(64,'0')
      public_key = group.generator.multiply_by_scalar(private_key)
      public_key_hex = Ant::ECDSA::Format::PointOctetString.encode(public_key, compression: true).unpack('H*')[0]
      address = Ant::Wallet::Util.pubkey_to_address public_key_hex
      encrypted_privkey = Ant::Wallet::Util.to_bip38(passwd, private_key_hex, address)
      private_key_hex2, public_key2 = Ant::Wallet::Util.from_bip38(encrypted_privkey, passwd, address)
      if private_key_hex == private_key_hex2
        keys = [encrypted_privkey, public_key_hex, address]
      end
      keys
    end

  end
end
