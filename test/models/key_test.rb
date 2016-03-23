require 'test_helper'

class KeyTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test 'should not save a key without a resource and key chain' do
    key = Key.new
    key.save
    assert_not key.valid?

    key = Key.new(resource: users(:student1))
    key.save
    assert_not key.valid?

    key = Key.new(key_chain: key_chains(:admin))
    key.save
    assert_not key.valid?
  end
end
