require 'edurange'
include Edurange
require 'spec_helper'

Edurange.logger.level = Logger::WARN
describe "An instance" do
  before(:each) do
    @subnet = FactoryGirl.build(:subnet)
    @instance = FactoryGirl.build(:instance)
  end
  it "should not be valid without an OS" do
    @instance.os = nil
    @instance.valid?.should be_false
  end
  it "should not be valid without an IP" do
    @instance.ip = nil
    @instance.valid?.should be_false
  end
  it "should not be valid without a subnet" do
    @instance.subnet = nil
    @instance.valid?.should be_false
  end
  it "should not be valid if an IP is specified outside of its subnet's block"# do
    #@instance.ip = '11.0.0.0'
    #@instance.valid?.should be_false
  #end
  it "should be valid if an IP is specified within its subnet's block" do
    @instance.ip = '10.0.0.4'
    @instance.valid?.should be_true
  end

  context "that has a valid subnet and IP" do
    before(:each) do
      @scenario = FactoryGirl.create(:scenario)
      @monitoring_unit = @scenario.monitoring_units.first
      @subnet = @monitoring_unit.subnets.first
      @instance = @subnet.instances.first
    end
    it "should accept a user group" do
      @group = FactoryGirl.build(:group)
      @instance.add_user @group
      @instance.groups.should include(@group)
      @instance.administrators.should_not include(@group)
      @instance.users.should include(@group)
    end
    it "should accept an administrative group" do
      @group = FactoryGirl.build(:group)
      @instance.add_administrator @group
      @instance.groups.should include(@group)
      @instance.administrators.should include(@group)
      @instance.users.should_not include(@group)
    end
    it "should not be bootable" do
      expect { @instance.boot }.to raise_error
    end
  end
end
