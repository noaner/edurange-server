class UserMailer < ApplicationMailer
    layout false
    default from: 'higgz.test@gmail.com'

    def email_credentials(user, password)
        @user = user
        @password = password
        mail(to: user.email, subject: 'Welcome EDURange Instructor')
    end

    def test_email(email)
        mail(to: email, subject: 'EDURange test')
    end

end
