class Statistic < ActiveRecord::Base
	belongs_to :user
	has_one :scenario
    
    attr_accessor :bash_histories  # like @bash_histories
    
    after_initialize do |statistic|
    	puts "Statistic has been instantiated."
    end

end
