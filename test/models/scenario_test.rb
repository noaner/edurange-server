require 'test_helper'

class ScenarioTest < ActiveSupport::TestCase

  test 'should only allow instructor and admin to create scenario' do
    student = users(:student1)
    instructor = users(:instructor1)
    admin = users(:admin1)

    scenario = student.scenarios.new(location: :test, name: 'test1')
    scenario.save
    assert_not scenario.valid?
    assert_equal [:user], scenario.errors.keys

    scenario = instructor.scenarios.new(location: :test, name: 'test1')
    scenario.save
    assert scenario.valid?
    assert_equal [], scenario.errors.keys
  end

  test 'should rescue when yml is corrupted' do
    instructor = users(:instructor1)
    scenario = instructor.scenarios.new(location: :test, name: 'badyml')
    scenario.save
    assert_equal [:load], scenario.errors.keys

    scenario = instructor.scenarios.new(location: :test, name: 'badyml2')
    scenario.save
    assert_equal [:load], scenario.errors.keys
  end

  test 'production scenarios should load' do
    instructor = users(:instructor1)
    Dir.foreach('scenarios/production') do |filename|
      next if ['.','..'].include? filename
      scenario = instructor.scenarios.new(location: :production, name: filename)
      scenario.save
      assert_equal [], scenario.errors.keys, "production scenario #{filename} does not load. #{scenario.errors.messages}"
    end
  end

end