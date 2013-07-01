require 'settingslogic'
require 'aws-sdk'
require 'yaml'
require 'pry'
require 'logger'
require 'optparse'
require 'pp'

require 'edurange/version'
require 'edurange/settings'
require 'edurange/logger'
require 'edurange/helper'
include Edurange

require 'edurange/parser'
require 'edurange/puppet_master'
require 'edurange/instance'
require 'edurange/runtime'
