require 'test_helper'

class RoleTest < ActiveSupport::TestCase

  test 'package addition and removal' do
    role = roles(:test_role)

    assert_equal role.id, 344
    assert role.packages.empty?

    # add a package
    role.package_add 'foo'
    assert_equal role.packages, ['foo']

    # don't allow duplicate packages
    role.package_add 'foo'
    assert role.errors.any?
    assert_equal role.packages, ['foo']

    # clear errors for next test
    role.errors.clear
    assert_not role.errors.any?

    # don't allow packages to be adde while an instance using role is not stopped
    role.scenario.instances.first.update_attribute(:status, 'booted')
    role.reload
    role.package_add 'foo2'
    role.reload

    assert role.errors.any?
    assert_equal ['foo'], role.packages

    role.scenario.instances.first.update_attribute(:status, 'stopped')
    role.reload

    # clear errors for next test
    role.errors.clear
    assert_not role.errors.any?
    role.package_add 'foo3'

    assert_not role.errors.any?
    assert_equal ['foo', 'foo3'], role.packages

    # try remove package while and instance using it is booted
    role.scenario.instances.first.update_attribute(:status, 'booted')
    role.reload
    role.package_remove 'foo2'
    role.reload

    assert role.errors.any?
    assert_equal ['foo', 'foo3'], role.packages

    # try remove package while instance is stopped
    role.scenario.instances.first.update_attribute(:status, 'stopped')
    role.reload
    role.package_remove 'foo3'
    role.reload

    assert_not role.errors.any?
    assert_equal ['foo'], role.packages

    # try remove package that doesn't exist
    role.package_remove 'notexist'
    role.reload

    assert role.errors.any?
    assert_equal ['foo'], role.packages

    # try remove last package
    role.package_remove 'foo'
    role.reload

    assert_not role.errors.any?
    assert_equal [], role.packages

    # try remove package that doesn't exist
    role.package_remove 'notexists'
    role.reload

    assert role.errors.any?
    assert_equal [], role.packages
    role.errors.clear

    # do not allow blank packages or non String names
    role.package_add ''
    role.reload

    assert role.errors.any?
    assert_equal [], role.packages
    role.errors.clear

    role.package_add 3
    role.reload

    assert role.errors.any?
    assert_equal [], role.packages

  end

end