class Key < ActiveRecord::Base
  belongs_to :resource, polymorphic: true
  belongs_to :key_chain
end
