class Scenario < ActiveRecord::Base
  include Provider
  include AWS
  attr_accessor :template # For picking a template when creating a new scenario
  has_many :clouds, dependent: :delete_all
  validates_presence_of :name, :description

  def debug(message)
    log = self.log
    self.update_attributes(log: log + message + "\n")
    PrivatePub.publish_to "/scenarios/#{self.id}", log_message: message
  end
end
