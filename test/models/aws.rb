require 'test_helper'

class RecipeTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test 's3 chef error' do
  	instance = instances(:s3test)
  	init = instance.generate_init
  	# need chef installed to do test
  end

end