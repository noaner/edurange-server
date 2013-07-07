module Edurange
  # Create global ec2 client, so we don't have to instantiate this everywhere (also helps with stubbing in future...)
  @@ec2 = AWS::EC2::Client.new
  def self.ec2
    @@ec2
  end

  class Runtime
    # ==== Attributes
    # 
    # * +config_filename+ - Takes a YAML configuration file.
    #
    # === Usage
    #
    #   Edurange::Runtime.start(yaml_file)
    def self.start(config_filename)
      file = File.open config_filename
      # Parse the configuration file, extract list of nodes
      nodes = Edurange::Parser.parse_yaml(file)
    end
  end
end
