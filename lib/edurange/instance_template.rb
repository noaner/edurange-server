module Edurange
  class InstanceTemplate
    attr_accessor :instance, :filepath
    def initialize(instance)
      self.instance instance
    end
    def generate_cookbook
      template = File.read("templates/cookbook_template.rb.erb")
      template = Erubis::Eruby.new(template)
      template.result(users: instance.users)
    end
    def generate_cloud_init(cookbook_url)
      # Returns the bash code to initialize an instance with chef-solo
      template = File.read("templates/bootstrap_template.sh.erb")
      template = Erubis::Eruby.new(template)
      result = template.result(cookbook_url: cookbook_url)
    end
  end
end
