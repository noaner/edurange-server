module Edurange
  class Chef
    attr_accessor :instance, :filepath
    def initialize(instance)
    end
    def generate_cookbooks
      vpc = @instance.vpc
    end
  end
end
