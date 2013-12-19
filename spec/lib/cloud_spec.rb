require 'edurange'
include Edurange
require 'spec_helper'

Edurange.logger.level = Logger::WARN
describe "A cloud" do
  before(:each) do
    @cloud = FactoryGirl.build(:cloud)
  end
  it "should be able to add a subnet" do
    @subnet = FactoryGirl.build(:subnet)
    @subnet.should_receive(:cloud=).with(@cloud)
    @cloud.subnets.should_receive(:push).with(@subnet)
    @cloud.add @subnet
  end
  it "should have a nil vpc_id" do
    @cloud.vpc_id.should be_nil
  end
  it "should boot its subnets in correct order" do
    AwsCloudService.any_instance.should_receive(:create_cloud)
    @subnet1 = FactoryGirl.build(:subnet)
    @subnet2 = FactoryGirl.build(:subnet)
    @cloud.add @subnet1
    @cloud.add @subnet2

    @subnet1.should_receive(:boot).ordered
    @subnet2.should_receive(:boot).ordered

    @subnet1.should_receive(:boot_subnet_instances).ordered
    @subnet2.should_receive(:boot_subnet_instances).ordered

    @subnet1.should_receive(:bootstrap_subnet).ordered
    @subnet2.should_receive(:bootstrap_subnet).ordered

    @cloud.boot
  end
end
