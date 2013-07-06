module Edurange

  @@ec2_connection = AWS::EC2::Client.new
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
