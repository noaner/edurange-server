class InstanceTemplate
  attr_accessor :instance, :filepath
  def initialize(instance)
    self.instance = instance
  end

  def generate_cookbook_new
    begin
      template = File.read(Settings.app_path + "lib/templates/cookbook_template_new.rb.erb")
      template = Erubis::Eruby.new(template)

      template2 = File.read(Settings.app_path + "scenarios/default/#{instance.subnet.cloud.scenario.name.downcase}/cookbook.rb.erb")
      template2 = Erubis::Eruby.new(template2)

      # do finish script
      template3 = File.read(Settings.app_path + "lib/templates/cookbook_finished.rb.erb")
      template3 = Erubis::Eruby.new(template3)

      template.result(instance: instance) + "\n" + template2.result(instance: instance) + "\n" + template3.result(instance: instance)
      # template.result(instance: instance) + "\n" + template3.result(instance: instance)
    rescue
      raise
      return
    end
  end

  def generate_cookbook
    begin
      template = File.read(Settings.app_path + "lib/templates/cookbook_template.rb.erb")
      template = Erubis::Eruby.new(template)
      template.result(scenario: instance.subnet.cloud.scenario, scoring_url: instance.scoring_url, users: instance.users, administrators: instance.administrators, roles: instance.roles)
    rescue
      raise
      return
    end
  end
  def generate_cloud_init(cookbook_url)
    begin
    # Returns the bash code to initialize an instance with chef-solo
      template = File.read(Settings.app_path + "lib/templates/bootstrap_template.sh.erb")
      template = Erubis::Eruby.new(template)
      result = template.result(cookbook_url: cookbook_url, instance: self.instance)
    rescue
      raise
      return
    end
  end
  # Must set self.filepath to s3/http/https url
  def aws_provider_upload
    begin
      cookbook = self.generate_cookbook
      self.filepath = S3::upload(cookbook)
    rescue
      raise
      return
    end
  end
end
