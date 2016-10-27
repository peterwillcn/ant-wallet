require 'jsonrpc/client'

module Ant::Wallet
  class Queue
    #include Wisper::Publisher

    attr_accessor :address, :block_height

    def initialize addrs, client=nil
      Ant::Wallet.logger.level = ::Logger::WARN
      JSONRPC.logger = Ant::Wallet.logger
      @address = addrs
      @db = Ant::Wallet::Store.new(Ant::Wallet::HOME + 'data.db')
      @client = client || JSONRPC::Client.new(Ant::Wallet::BCHOST)
    end

    def fix_data height, max_height
      max_height = nil if max_height == 0
      while (max_height || @client.getblockcount) >= height do
        block = @client.getblock height, 1
        store_transaction block, @address
        p height += 1
        sleep 0.5
      end
      @db.close
    end

    def run
      loop do
        @block_height = @client.getblockcount - 1
        block = @client.getblock @block_height, 1
        store_transaction block, @address
        sleep 16
      end
      @db.close
    end

private

    def store_transaction(block, addrs=[])
      height = block["height"]
      txs = block["tx"]
      txs.each do |tx|
        txid = tx["txid"]
        txouts = tx["vout"]
        txouts.each do |vout|
          address = vout['address']
          if addrs.include? address
            dml = { address: address, height: height,
              prev_tx_output_hash: txid,
              prev_tx_output_index: vout['n'],
              asset_id: vout['asset'],
              balance: vout['value'], state: 'Y' }
            @db.insert('txouts', dml)
          end
        end
      end
    end

  end
end
