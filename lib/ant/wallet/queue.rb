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

    def fix_data height
      while @client.getblockcount >= height do
        block = @client.getblock height, 1
        prev = find_transaction_at_block block, @address
        insert_transaction prev, @address, height
        p height += 1
        sleep 0.5
      end
    end

    def run
      loop do
        @block_height = @client.getblockcount - 1
        block = @client.getblock @block_height, 1
        prev = find_transaction_at_block block, @address
        insert_transaction prev, @address, block_height
        sleep 16
      end
    end

private

    def insert_transaction prev, addrs, height
      txs = prev[height]
      txs.each do |addr, out|
        if addrs.include? addr
          txid = out[0]
          txindex = out[1]
          address = out[2]
          balance = out[3]
          asset_id = 'ANS' #out[4]

          dml = { address: address, height: height,
            prev_tx_output_hash: txid,
            prev_tx_output_index: txindex,
            asset_id: asset_id,
            balance: balance, state: 'Y' }
          @db.insert('txouts', dml)
        end
      end
    end

    def find_transaction_at_block(block, addrs=[])
      txids = {}
      block["tx"].each do |t|
        t["vout"].each do |v|
          addrs.each do |addr|
            if v["address"] == addr and v["asset"] == Ant::Wallet::TYPE
              txids.merge!({addr =>[ t["txid"],
               v["n"],
               v["address"],
               v["value"],
               v["asset"]
             ]})
            end
          end
        end
      end
      { block["height"] => txids }
    end

  end
end
