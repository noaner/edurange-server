require 'test_helper'

class AdminUITest < ActionDispatch::IntegrationTest

	test 'sign in' do
		visit('/')

		sign_in_form = page.all('form')[0]

		assert /users\/sign_in/.match(sign_in_form['action']) != nil
	end

end