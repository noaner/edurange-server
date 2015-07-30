class Statistic < ActiveRecord::Base
	belongs_to :user
	has_one :scenario
    
    attr_accessor :bash_histories  # like @bash_histories
   
    def populate_bash_histories(scenario)
    	scenario.instances.all.each do |intsance|
    		self.bash_histories += instance.get_bash_history
    	end
    end

    def bash_analytics(relevant_commands)
    	options_frequencies = Hash.new(0)
    	bash_history = self.bash_histories.split("\n")
    	bash_history.each do |command|
    		options = command.scan(/[-'[A-Za-z]]+/);
    		options.each do |option|
    			options_frequencies[option] += 1;
    		end
    	end	
    	options_frequencies.sort_by { |option| option[1] }
    end

end