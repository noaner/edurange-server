class Statistic < ActiveRecord::Base
	belongs_to :user
	has_one :scenario
    
    # active directory has support for arrays and hash tables
    serialize :bash_analytics


	## utility methods
	def unix_to_dt(ts)
	  # convert unix timestamp to datetime object
	  return DateTime.strptime(ts, format="%s")
	end


	def dates_in_window(start_time, end_time, timestamps)
    # input -> start_time, end_time: datetime objects defining
    #                                a window of time
    #          timestamps: a hash from corresponding to a specific user
    #             of the form {timestamp -> command}
    # output -> dates: a list of timestamps within a window of time
    window = timestamps.keys.select{ |d| unix_to_dt(d) >= start_time \
                                        && unix_to_dt(d) <= end_time }
    return window
	end

	def is_numeric?(s)
    # input -> s: a string
    # output -> true if the string is a number value, false otherwise
    begin
      if Float(s)
        return true
      end
    rescue
      return false
    end
	end

	## end utility methods

  # private

    def perform_analytics(data)
      # input -> data: a hash of the form { users -> list of strings of commands }
      # output -> results: a nested array of two-element arrays
      results = []  # [[ string, count ]]
      frequencies = Hash.new(0)
      data.keys.each do | user |
        data[user].each do | cmd |
          if !frequencies.include?(cmd)
            frequencies[cmd] = 1
          else
            frequencies[cmd] += 1
          end
        end
      end
      return frequencies
    end


    def grab_relevant_commands(users, start_time, end_time, data)
	    # input -> users: a list of username strings
	    #          start_time, end_time: strings which represent dates
	    #                                that define a window of time
	    # output -> a dictionary mapping users to a list of
	    #           commands they've entered during a window of time

	    # method params determine portion of bash data which is relevant
	    result = Hash.new(0)  # {user -> relevant-commmands}
	    start_time = unix_to_dt(start_time)
	    end_time = unix_to_dt(end_time)
	    bash_data = self.bash_analytics  # yank the data from model

	    if users.length == 1  # single user
        u = users[0]  # grab that user and,
        timestamps = bash_data[u]  # create {timestamps -> command} from {user -> {timestamps -> command}}
        # grab list of timestamps within specified window of time
        window = dates_in_window(start_time, end_time, timestamps)         
        cmds = []  # to be array of commands within window
        window.each do |d|
          cmds << timestamps[d]
        end
        result[u] = cmds  # {user -> array of relevant commands}
        return result
	    elsif users.length > 1  # many users
        users.each do |u| # same as above but for each user
          cmds = []
          timestamps = bash_data[u]
          window = dates_in_window(start_time, end_time, timestamps)
          window.each do |d|
              cmds << timestamps[d]
          end
          result[u] = cmds
        end
        return result # users that map to lists of strings of commands
	    # empty hash (no commands within timeframe?)
	    else
	      return result  
	    end
    end

  end # end private methods

end  # end statistic model