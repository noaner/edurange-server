module Edurange
  class Runtime
    # ==== Attributes
    # 
    # * +config_filename+ - Takes a YAML configuration file.
    #
    # === Usage
    #
    #   Edurange::Runtime.init(yaml_file)
    def self.start(config_filename)

      # Gets name of key file in use from config.yml, depends on line number 
      # keyname = IO.readlines(File.expand_path('~/.edurange/config.yml'))[0].gsub("ec2_key:", "").strip
      keyname = Settings.ec2_key
      
      # Parse the configuration file, extract list of nodes
      nodes = Edurange::Parser.parse_yaml(config_filename, keyname) # format: nodes[node_name, ami_id, users, firewall_rules, packages]
    end
  end
end
