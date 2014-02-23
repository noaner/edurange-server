require 'socket'
require 'timeout'
require 'settingslogic'
require 'aws-sdk'
require 'yaml'
require 'ipaddr'
require 'pry'
require 'logger'
require 'optparse'
require 'pp'
require 'bombshell'
require 'open-uri'
require 'active_record'
require 'sqlite3'
require 'erubis'

require 'edurange/version'
require 'edurange/settings'
require 'edurange/logger'
require 'edurange/helper'
include Edurange

require 'edurange/management'
require 'edurange/parser'
require 'edurange/database'
require 'edurange/scenario'
require 'edurange/cloud'
require 'edurange/subnet'
require 'edurange/instance'
require 'edurange/instance_role'
require 'edurange/instance_group'
require 'edurange/instance_template'
require 'edurange/instance'
require 'edurange/role'
require 'edurange/group'
require 'edurange/player'
require 'thread/pool'

#require 'edurange/runtime'

require 'edurange/drivers/aws' # TODO dynamic based on flag

require 'edurange/ecli/shell'
require 'edurange/ecli/info'

debug "Required all files necessary. Starting up..."
