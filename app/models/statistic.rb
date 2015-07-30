class Statistic < ActiveRecord::Base
	belongs_to :user
	has_one :scenario

end