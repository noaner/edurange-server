require 'factory_girl'
FactoryGirl.define do
  sequence(:vpc_id) { |i| "vpc-#{i}" }
  factory :instance do
    name "Test Instance"
    ami_id "ami-e720ad8e"
    ip_address "10.0.128.21"
    factory :nat_instance do
      is_nat true
      ip_address "10.0.128.5"
    end
    uuid { `uuidgen` }
  end
  # Plain old subnet
  factory :subnet do 
    cidr_block "10.0.128.16/28"
    # Running nat subnet with instance
    factory :nat_subnet do
      cidr_block "10.0.128.0/28"
      is_nat true
    end
    factory :running_subnet do
      running true
    end
  end
  # Plain old cloud
  factory :cloud do
    cidr_block "10.0.0.0/16"
  end
end
