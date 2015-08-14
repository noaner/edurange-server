module ActiveRecord
	class Base
		def self.reset_pk_sequence
			case ActiveRecord::Base.connection.adapter_name
			when 'SQLite'
				new_max = maximum(primary_key) || 0
				update_seq_sql = "update sqlite_sequence set seq = #{new_max} where name = '#{table_name}';"
				ActiveRecord::Base.connection.execute(update_seq_sql)
			else
				puts "Database adapter is not supported."
		end
	end
end
