require 'spec_factory'
require 'rspec'
require 'aws-sdk'
require 'vcr'
 
VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/vcr_cassettes'
end
 
RSpec.configure do |c|
  c.around(:each) do |example|
    VCR.use_cassette(example.metadata[:full_description]) do
      example.run
    end
  end
end
