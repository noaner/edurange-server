require 'edurange'
include Edurange
require 'spec_helper'

Edurange.logger.level = Logger::WARN
describe "An instance" do
  before(:each) do
    @instance = FactoryGirl.build(:instance)
  end
  it "should not be a nat instance" do
    @instance.is_nat.should be_false
  end
  it "should not be running" do
    @instance.running.should be_false
  end
  it "should not have a subnet" do
    @instance.subnet.should be_nil
  end
  it "should not have users" do
    @instance.users.should == []
  end

  context "that is booted" do
    before(:each) do
      @cloud = FactoryGirl.build(:cloud)
      @subnet = FactoryGirl.build(:subnet)
      @cloud.add @subnet
      @subnet.add @instance

      ChefService.any_instance.stub(:bootstrap_chef)
      ChefService.any_instance.stub(:sleep_until_configurable)
      ChefService.any_instance.stub(:configure_cookbooks)
      AwsInstanceService.any_instance.stub(:create_instance).and_return(double(id: 'i-1234567'))

      @instance.boot
    end

    # Asserting instance does not throw away attributes and they are readable
    it "should be running" do
      @instance.running.should be_true
    end
    it "should have an IP" do
      @instance.ip_address.should_not be_nil
    end
    it "should have a name" do
      @instance.name.should_not be_nil
    end
    it "should have a subnet" do
      @instance.subnet.valid?.should be_true
    end
    it "should belong to a normal subnet" do
      @instance.subnet.is_nat?.should be_false
    end
  end
  context "that is a nat instance" do
    before(:each) do
      @cloud = FactoryGirl.build(:cloud)
      @subnet = FactoryGirl.build(:nat_subnet)
      @instance = FactoryGirl.build(:nat_instance)
      @cloud.add @subnet
      @subnet.add @instance

      ChefService.any_instance.stub(:bootstrap_chef)
      ChefService.any_instance.stub(:sleep_until_configurable)
      ChefService.any_instance.stub(:configure_cookbooks)
      AwsInstanceService.any_instance.stub(:create_instance).and_return(double(id: 'i-1234568'))

    end
    it "is a nat instance" do
      @instance.is_nat?.should be_true
    end

    context "that is booted" do
      before(:each) do
        @instance.boot
      end
      it "should belong to a NAT subnet" do
        @instance.subnet.is_nat?.should be_true
      end
      context "that is configured for chef" do
        before(:each) do
          AWS.stub!
          
          #Stub methods with hardcoded sleeps, etc
          @instance.stub(:sleep_until_running)
          @instance.stub(:sleep_for_elastic_ip)

          # Stub EIP creation
          eip = AWS::EC2::ElasticIp.new('123.123.123.123')
          AWS::EC2::ElasticIpCollection.any_instance.stub(:create).and_return(eip)

          # Stub EIP assignment
          @instance.aws_object = double
          @instance.aws_object.should_receive(:associate_elastic_ip).with(eip)

          # Stub NAT stuff
          interface = double("source_dest_check" => true)
          interface.should_receive(:source_dest_check=).with(false)
          @instance.aws_object.should_receive(:network_interfaces).and_return([interface])

          @instance.prepare_for_bootstrap
        end
        it "should have an elastic IP" do
          @instance.elastic_ip.should_not be_nil
        end
      end
    end
  end
end
