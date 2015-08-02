class Statistic < ActiveRecord::Base
	belongs_to :user
	has_one :scenario
    
    # active directory has support for arrays and hash tables
    serialize :bash_analytics
end