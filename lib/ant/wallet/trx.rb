module Ant::Wallet
  class Trx

    def initialize(addr2, amount, addr1, type, password)
      @amount, @addr1, @type = amount, addr1, type
      @spent_ids = []
      @db = Ant::Wallet::Store.new(Ant::Wallet::HOME + 'data.db')
      Ant::Wallet.logger.level = ::Logger::WARN
      JSONRPC.logger = Ant::Wallet.logger
      @client = JSONRPC::Client.new Ant::Wallet::BCHOST
      @from = Ant::Wallet::Util.hash160_from_address @addr1
      @to = Ant::Wallet::Util.hash160_from_address addr2
      private_key, public_key = Ant::Wallet::Util.from_bip38(
        @db.find('wallets',@addr1)[0][2], password, @addr1)
      @tx = Ant::Protocol::Tx.new 0x80, 0x00, private_key.to_i(16), public_key
      @unspent = @db.find_tx 'txouts', @addr1
    end

    def utxo
      balance, value, sum = 0, 0, 0

      unless @unspent.empty?
        @unspent.each do |t|
          unless t.empty?
            value = t[6].to_i
            if value == @amount
              @tx.add_in Ant::Protocol::TxIn.new(t[3], t[4])
              @spent_ids << t[0]
              sum = value
              break
            elsif @amount >= value
              sum += value
              @tx.add_in Ant::Protocol::TxIn.new(t[3], t[4])
              @spent_ids << t[0]
              break if sum >= @amount
            else
              sum = value
              balance = sum - @amount
              @tx.add_in Ant::Protocol::TxIn.new(t[3], t[4])
              @spent_ids << t[0]
            end
          end
        end

      end

      unless @tx.in.nil?
        @tx.add_out Ant::Protocol::TxOut.new(@type, balance, @from) if balance > 0
        @tx.add_out Ant::Protocol::TxOut.new(@type, @amount, @to)
      end

    end

    def send_hex
      #utxo
      unless @spent_ids.empty?
        p hex = @tx.generate_tx_hex.unpack('H*')[0]
        status = @client.sendrawtransaction hex
        @db.update_tx('txouts', @spent_ids.join(','), 'N') if status
      end
      status
    end

  end
end
