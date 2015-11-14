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

  test 'clone' do
    instructor = users(:instructor999999999)
    scenario = instructor.scenarios.new(location: :test, name: 'test1')
    scenario.save

    assert_equal [], scenario.errors.keys

    clone = scenario.clone('test1clone')
    clone.save
    assert_equal [], scenario.errors.keys

    path = clone.path
    path_yml = clone.path_yml
    path_recipes = clone.path_recipes

    assert path
    assert path_yml
    assert path_recipes

    path_graveyard_scenario = clone.obliterate

    assert_not File.exists? path
    assert_not File.exists? path_yml
    assert_not File.exists? path_recipes

    path_graveyard = "#{Settings.app_path}/scenarios/custom/graveyard"
    path_graveyard_user = "#{path_graveyard}/#{instructor.id}"
    path_graveyard_scenario_yml = "#{path_graveyard_scenario}/#{clone.name.downcase}.yml"
    
    assert File.exists? path_graveyard
    assert File.exists? path_graveyard_user
    assert File.exists? path_graveyard_scenario
    assert File.exists? path_graveyard_scenario_yml

    FileUtils.rm_r "#{Settings.app_path}/scenarios/custom/#{instructor.id}"
    FileUtils.rm_r path_graveyard_user

  end

  test 'scenario should not fail if recipe folders are missing' do
    instructor = users(:instructor999999999)
    scenario = instructor.scenarios.new(location: :test, name: 'missingrecipefolder')

    assert File.exists? "#{scenario.path}/recipes"
    FileUtils.rmdir "#{scenario.path}/recipes"
    assert_not File.exists? "#{scenario.path}/recipes"

    scenario.save

    assert_not scenario.errors.any?
    assert File.exists? "#{scenario.path}/recipes"

  end

  test 'answers_url should not be nil' do
    instructor = users(:instructor999999999)
    scenario = instructor.scenarios.new(location: :test, name: 'test1')
    scenario.save
    assert scenario.answers != nil
    assert scenario.answers.class == String
  end

end