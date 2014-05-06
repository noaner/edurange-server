class InstanceTemplate < ActiveRecord::Base
  attr_accessor :instance, :filepath
  def initialize(instance)
    self.instance = instance
  end
  def generate_cookbook
    template = File.read("lib/templates/cookbook_template.rb.erb")
    template = Erubis::Eruby.new(template)
    info instance.roles
    template.result(users: instance.users, administrators: instance.administrators, roles: instance.roles)
  end
  def generate_cloud_init(cookbook_url)
    # Returns the bash code to initialize an instance with chef-solo
    template = File.read("lib/templates/bootstrap_template.sh.erb")
    template = Erubis::Eruby.new(template)
    result = template.result(cookbook_url: cookbook_url, instance: self.instance)
  end
end
