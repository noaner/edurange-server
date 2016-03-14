class KeyChain < ActiveRecord::Base
    has_many :keys
    has_and_belongs_to_many :users
end
