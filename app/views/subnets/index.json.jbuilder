json.array!(@subnets) do |subnet|
  json.extract! subnet, :id, :name, :cidr_block, :driver_id, :internet_accessible, :cloud_id
  json.url subnet_url(subnet, format: :json)
end
