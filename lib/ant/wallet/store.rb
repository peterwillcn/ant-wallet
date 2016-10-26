require "sqlite3"

module Ant::Wallet
	class Store
	  def initialize(path = nil)
      @db = SQLite3::Database.new path
    end

    def create_table ddl
      @db.execute ddl
    # ensure
    #   @db.close
    end

    def close
      @db.close
    end

    def insert table, datas
    	flag, columns, values = '', '', []
      datas.size.times {flag += '?,' }
      datas.each_key {|key| columns += key.to_s + ',' }
      datas.each_value {|value| values << value }
      @db.execute "insert into #{table} ( #{columns.chop} ) values ( #{flag.chop} )", values
    end

    def select table
      @db.execute "select * from #{table}"
    end

    def delete table
      @db.execute "delete from #{table}"
    end

    def find table, address
      @db.execute "select * from #{table} where address == '#{address}'"
    end

    def find_tx table, address
      @db.execute "select * from #{table} where address == '#{address}' and state = 'Y' order by balance"
    end

    def find_hex table, id
      @db.execute "select * from #{table} where id == '#{id}'"
    end

    def find_all_tx table
      @db.execute "select * from #{table} where and state = 'Y' order by balance"
    end

    def update_tx table, ids, state
      @db.execute "update #{table} set state = '#{state}' where id in (#{ids})"
    end

  end
end
