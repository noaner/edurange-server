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
  it "should not be a nat subnet" do
    @subnet.is_nat.should be_false
  end
  it "should not be running" do
    @subnet.running.should be_false
  end
  it "should not have instances" do
    @subnet.instances.should == []
  end
  it "should have a cidr_block" do
    @subnet.cidr_block.should_not be_nil
  end
  it "should be able to add an instance" do
    @instance = FactoryGirl.build(:instance)
    @instance.should_receive(:subnet=).with(@subnet)
    @subnet.add @instance
    @subnet.instances.should include(@instance)
  end
  it "should get its ID from aws" do
    @subnet.aws_object = double
    @subnet.aws_object.should_receive(:id).and_return("subnet-c12345")
    @subnet.subnet_id.should == "subnet-c12345"
  end
  it "should be able to run" do
    @cloud = FactoryGirl.build(:cloud)
    @cloud.add @subnet
    AwsSubnetService.any_instance.should_receive(:create_subnet)
    AwsSubnetService.any_instance.should_receive(:create_route_table)
    @subnet.should_receive(:boot_subnet_instances)
    @subnet.boot
    @subnet.running.should be_true
  end
  it "should boot instances when booting" do
    @instance = FactoryGirl.build(:instance)
    @subnet.add @instance

    @instance.should_receive(:boot)
    @subnet.boot_subnet_instances
  end
  context "that is running" do
    before(:each) do
      @subnet = FactoryGirl.build(:subnet)
      @instance = FactoryGirl.build(:instance)
      @subnet.add @instance
    end
    it "should be able to tell instances to bootstrap themselves" do
      # Only tests a subnet telling an instance to bootstrap itself
      @instance.should_receive(:bootstrap_instance_with_chef)
      @subnet.bootstrap_subnet_instances
    end
    it "should prep itself for bootstrapping before telling instances to bootstrap" do
      @subnet.should_receive(:configure_subnet_for_chef)
      @subnet.should_receive(:bootstrap_subnet_instances)
      @subnet.should_receive(:configure_subnet_for_edurange)
      @subnet.bootstrap_subnet
    end
    it "should be able to configure itself for bootstrapping via AwsSubnetService" do
      AwsSubnetService.any_instance.should_receive(:configure_subnet_for_chef)
      @subnet.configure_subnet_for_chef
    end
    it "should be able to configure itself for edurange via AwsSubnetService" do
      AwsSubnetService.any_instance.should_receive(:configure_subnet_for_edurange)
      @subnet.configure_subnet_for_edurange
    end
    it "should boot & bootstrap an added instance" do
      # In here, we are testing that a running subnet properly adds an instance.
      # This requires it to:
      @subnet = FactoryGirl.build(:running_subnet)
      # - call boot on instance
      @instance.should_receive(:boot)
      # - change networking to chef
      @subnet.should_receive(:configure_subnet_for_chef)
      # - call bootstrap on instance
      @instance.should_receive(:bootstrap_instance_with_chef)
      # - change networking back to edurange
      @subnet.should_receive(:configure_subnet_for_edurange)

      @subnet.add @instance
    end
  end
end
