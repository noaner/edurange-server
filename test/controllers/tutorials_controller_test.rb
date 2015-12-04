require 'test_helper'

class TutorialControllerTest < ActionController::TestCase

	include Devise::TestHelpers

	def setup
		@controller = TutorialsController.new
	end

  test "should get index" do

		u = users(:student1)
		sign_in(u)

    get :index
    assert_response :success
  end

end
