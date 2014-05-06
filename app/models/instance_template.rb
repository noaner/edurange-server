class InstanceTemplate
  attr_accessor :instance, :filepath
  def initialize(instance)
    self.instance = instance
  end
  def generate_cookbook
    template = File.read("lib/templates/cookbook_template.rb.erb")
    template = Erubis::Eruby.new(template)
    binding.pry
    template.result(users: instance.users, administrators: instance.administrators, roles: instance.roles)
    PrivatePub.publish_to "/scenarios/1", log_message: 'in generate cookbook'
  end
  def generate_cloud_init(cookbook_url)
    # Returns the bash code to initialize an instance with chef-solo
    PrivatePub.publish_to "/scenarios/1", log_message: 'in generate cloud init'
    template = File.read("lib/templates/bootstrap_template.sh.erb")
    PrivatePub.publish_to "/scenarios/1", log_message: 'in generate cloud init'
    template = Erubis::Eruby.new(template)
    PrivatePub.publish_to "/scenarios/1", log_message: 'in generate cloud init'
    result = template.result(cookbook_url: cookbook_url, instance: self.instance)
  end
  # Must set self.filepath to s3/http/https url
  def aws_provider_upload
    cookbook = self.generate_cookbook
    self.filepath = S3::upload(cookbook)
  end
end
