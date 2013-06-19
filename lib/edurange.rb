require 'edurange/version'
require 'edurange/parser'
require 'edurange/puppet_master'
require 'edurange/edu_machine'
require 'edurange/instance'
require 'edurange/helper'

module Edurange
  class Init
    # ==== Attributes
    # 
    # * +config_filename+ - Takes a YAML configuration file.
    #
    # === Usage
    #
    #   Edurange::Init.init(yaml_file)
    def self.init(config_filename)

      # Gets name of key file in use from config.yml, depends on line number 
      # keyname = IO.readlines(File.expand_path('~/.edurange/config.yml'))[0].gsub("ec2_key:", "").strip
      keyname = File.open(File.expand_path('~/.edurange/config.yml'), 'r') { |f| f.readline.gsub('ec2_key:', '').strip }
      
      # Parse the configuration file, extract list of nodes
      nodes = Edurange::Parser.parse_yaml(config_filename, keyname) # format: nodes[node_name, ami_id, users, firewall_rules, packages]
    end
  end
end
