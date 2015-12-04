class DynamicIP

	attr_reader :error, :str, :ip, :ip_min, :ip_max, :octets
  attr_writer :ip

	def initialize(str)
    @str = str
		if not str
			@error = "must supply string"
			return self
		end
		if not str.class == String
			@error = "initializer variable must be a string"
			return self
		end

		if not ((/^\d{1,3}(-\d{1,3})?\.\d{1,3}(-\d{1,3})?\.\d{1,3}(-\d{1,3})?\.\d{1,3}(-\d{1,3})?$/.match(str) != nil) and /\-/.match(str) != nil)
      @error = "not a valid dynamic IP address #{str}"
      return self
		end

    @ip_min = ""
    @ip_max = ""
    @octets = []

    str.split('.').each_with_index do |num, index|
      nums = num.split('-')
      a = nums[0].to_i

      # if a range
      if nums.size == 2
        b = nums[1].to_i 
        if not (a >= 0 and a <= 255) or not (b >= 0 and b <= 255)
          if index == 3
            @error = "octect #{index+1} range must be between 4 and 255"
          else
            @error = "octect #{index+1} range must be between 0 and 255"
          end
          @ip_min = nil
          @ip_max = nil
          return self
        end
        min = [a,b].min
        max = [a,b].max
        @ip_min << min.to_s
        @ip_max << max.to_s
      # if not a range
      else
        if not (a >= 0 and a <= 255)
          if index == 3
            @error = "last octect must be between 4 and 255"
          else
            @error = "octect #{index+1} must be between 0 and 255"
          end
          @ip_min = nil
          @ip_max = nil
          return self
        end
        min = a
        max = min
        @ip_min << min.to_s
        @ip_max << max.to_s
      end

      if index == 0
        if nums.size != 1
          @error = "first octect can not be range"
          @ip_min = nil
          @ip_max = nil
          return self
        end
        if a != 10
          @error = "first octect must be 10 (private class A network)"
          @ip_min = nil
          @ip_max = nil
          return self
        end
        @octets.push(10)
      else
        if min == max
          @octets.push(min)
        else
          @octets.push([min, max])
        end
      end

      @ip_min << '.'
      @ip_max << '.'

      
    end
    @ip_min = @ip_min.chop
    @ip_max = @ip_max.chop

    if @ip_min.split('.').last.to_i <= 3
      @error = "the last octect of your ip address must be greater than 3. numbers less than 3 are reserved"
      return self
    end

    if @ip_min == @ip_max
      @error = "ip max cannot equal ip min"
      return self
    end

    self.roll
	end

  def error?
    return @error != nil
  end

  def roll
    ipnew = ""
    ip = @ip
    @octets.each do |octet|
      if octet.class == Array
        ipnew << Random.new.rand(octet[0]..octet[1]).to_s
      else
        ipnew << octet.to_s
      end
      ipnew << '.'
    end
    ipnew = ipnew.chop
    if ipnew == ip
      return self.roll
    else
      @ip = ipnew
      return @ip
    end
  end

end