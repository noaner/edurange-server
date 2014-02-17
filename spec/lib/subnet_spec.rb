require 'edurange'
include Edurange
require 'spec_helper'


# What should a subnet be responsible for?
# - Subnet should talk to AWS Service layer to switch networking modes
# - Should be able to add instances
#   - If the subnet is not running, just set relationships up
#   - If subnet is running, boot instance, bootstrap it, then revert networking

Edurange.logger.level = Logger::WARN
describe "A subnet" do
  before(:each) do
    @subnet = FactoryGirl.build(:subnet)
  end

  it "must have a cidr block" do
    @subnet.cidr_block = nil
    @subnet.valid?.should be_false
  end

  it "must have a monitoring unit" do
    @subnet.monitoring_unit = nil
    @subnet.valid?.should be_false
  end

  its "cidr block must be within its monitoring unit's cidr block"

end
