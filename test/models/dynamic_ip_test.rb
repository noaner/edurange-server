require 'test_helper'

class DynamicIPTest < ActiveSupport::TestCase
  test "dynamic ip" do

    # errros
    dip = DynamicIP.new "0.0.0.4"
    assert dip.error?, dip.error

    dip = DynamicIP.new "10.255.255.255"
    assert dip.error?, dip.error
    
    dip = DynamicIP.new "10.0.0.4-266"
    assert dip.error?, dip.error
    
    dip = DynamicIP.new "0-20.0.0.4"
    assert dip.error?, dip.error
    
    dip = DynamicIP.new "10.0.0.4-4"
    assert dip.error?, dip.error

    dip = DynamicIP.new "10.0.0.0"
    assert dip.error?, dip.error

    dip = DynamicIP.new "10.0.0.1"
    assert dip.error?, dip.error

    dip = DynamicIP.new "10.0.0.2"
    assert dip.error?, dip.error

    dip = DynamicIP.new "10.0.0.0-3"
    assert dip.error?, dip.error

    # no errors
    dip = DynamicIP.new "10.0.0.4-5"
    assert_not dip.error?, dip.error
    
    dip = DynamicIP.new "10.0.0.4-255"
    assert_not dip.error?, dip.error
    
    dip = DynamicIP.new "10.0.10-11.4"
    assert_not dip.error?, dip.error
    
    dip = DynamicIP.new "10.50-2.10-20.4"
    assert_not dip.error?, dip.error
    
    dip = DynamicIP.new "10.50-2.10-20.255-255"
    assert_not dip.error?
    assert dip.ip_min == "10.2.10.255"
    assert dip.ip_max == "10.50.20.255"

    dip = DynamicIP.new "10.0.0.4-5"
    assert_not dip.error?, dip.error
    1000.times do
        ip = dip.ip
        dip.roll
        assert dip.ip != ip, "cur: #{ip}, new: #{dip.ip}"
    end

    dip = DynamicIP.new "10.0.0.4-22"
    assert dip.respond_to?(:octets)
    assert_not dip.error?
    

  end
end