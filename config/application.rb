require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Edurange
  class Application < Rails::Application

    # config.generators do |g|
    #   g.test_framework :rspec,
    #     fixtures: true,
    #     view_specs: false,
    #     helper_specs: false,
    #     routing_specs: false,
    #     controller_specs: false,
    #     request_specs: false
    #   g.fixture_replacement :factory_girl, dir: "spec/factories"
    # end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
    config.autoload_paths += %W(#{config.root}/lib)
    config.autoload_paths += Dir["#{config.root}/lib/**/"]

    # choose provider
    config.x.provider = 'aws'

    # AWS
    config.x.aws = config_for(:aws)

    # get iam user name and set some aws configs
    begin
      AWS::IAM::Client.new.create_access_key
    rescue => e
      config.x.aws['iam_user_name'] = /user\/.* is/.match(e.message).to_s.gsub("user\/", "").gsub(" is", "")
    end
    config.x.aws['s3_bucket_name'] = config.x.aws['iam_user_name']
    config.x.aws['ec2_key_pair_name'] = "#{config.x.aws['iam_user_name']}-#{config.x.aws['region']}"

    # create keypair if it doesn't already exist
    aws_key_pair_path = "#{Rails.root}/keys/#{config.x.aws['ec2_key_pair_name']}"
    FileUtils.mkdir("#{Rails.root}/keys") if not File.exists?("#{Rails.root}/keys")
    if not File.exists?(aws_key_pair_path)
      begin
        aws_key_pair = AWS::EC2::Client.new.create_key_pair(key_name: config.x.aws['ec2_key_pair_name'])
        File.open(aws_key_pair_path, "w") { |f| f.write(aws_key_pair[:key_material]) }
        FileUtils.chmod(0400, aws_key_pair_path)
      rescue
      end
    end

  end
end
