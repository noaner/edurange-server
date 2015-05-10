class InstanceTemplate
  attr_accessor :instance, :filepath
  def initialize(instance)
    self.instance = instance
  end

  def generate_cookbook
    begin
      cookbook = ""
      # This recipe sets up packages and users and is run for every instance
      cookbook += Erubis::Eruby.new(File.read(Settings.app_path + "scenarios/recipes/templates/packages_and_users.rb.erb")).result(instance: instance) + "\n"
      
      # Get cookbook recipe
      cookbook_path = "#{Settings.app_path}scenarios/local/#{instance.scenario.name.downcase}/cookbook.rb.erb"
      if File.exists? cookbook_path
        cookbook += Erubis::Eruby.new(File.read(cookbook_path)).result(instance: instance) + "\n"
      end

      # Get each recipe 
      local_path = "#{Settings.app_path}scenarios/local/#{instance.scenario.name.downcase}/recipes"
      shared_path = "#{Settings.app_path}scenarios/recipes"
      instance.roles.each do |role|
        role.recipes.each do |recipe|
          # First look for local recipe
          if File.exists? "#{local_path}/#{recipe}.rb.erb"
            cookbook += Erubis::Eruby.new(File.read("#{local_path}/#{recipe}.rb.erb")).result(instance: instance) + "\n"
          elsif File.exists? "#{shared_path}/#{recipe}.rb.erb"
            cookbook += Erubis::Eruby.new(File.read("#{shared_path}/#{recipe}.rb.erb")).result(instance: instance) + "\n"
          end
        end
      end
      # This recipe signals the com page and also gets the bash histories
      cookbook += Erubis::Eruby.new(File.read(Settings.app_path + "scenarios/recipes/templates/com_page_and_bash_histories.rb.erb")).result(instance: instance) + "\n"
      return cookbook
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
