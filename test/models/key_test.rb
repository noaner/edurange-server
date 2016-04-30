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

    key = Key.new(user: users(:admin1))
    key.save
    assert_not key.valid?

    key = Key.new(user: users(:admin1), resource: scenarios(:test1))
    assert key.valid?
  end

  test 'should save flag state' do
    key = Key.new(user: users(:admin1), resource: scenarios(:test1))

    key.can! :edit
    assert key.can? :edit
    key.cannot! :edit
    assert_not key.can? :edit

    key.set_all_flags(true)
    assert key.can? :edit
  end
end
