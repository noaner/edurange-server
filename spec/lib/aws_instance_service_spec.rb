require 'edurange'
include Edurange
require 'spec_helper'

Edurange.logger.level = Logger::WARN
describe "An Aws instance Service" do
  context "that is initialized with an instance" do
    before(:each) do
      @instance = FactoryGirl.build(:instance)
      @aws_instance_service = AwsInstanceService.new(@instance)
    end
    it "should be able to prepare for bootstrapping" do
      @instance.should_receive(:sleep_until_running)
      AwsHelper.should_receive(:associate_elastic_ip).with(@instance)
      @aws_instance_service.prepare_for_bootstrap
    end
  end
  context "that is initialized with a nat instance" do
    before(:each) do
      @instance = FactoryGirl.build(:nat_instance)
      @instance.aws_object = double
      @aws_instance_service = AwsInstanceService.new(@instance)
    end
    it "should be able to prepare for bootstrapping" do
      @instance.should_receive(:sleep_until_running)
      AwsHelper.should_receive(:associate_elastic_ip).with(@instance)
      @aws_instance_service.prepare_for_bootstrap
    end
  end
end
