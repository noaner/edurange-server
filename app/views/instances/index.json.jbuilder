json.array!(@instances) do |instance|
  json.extract! instance, :id, :name, :ip_address, :driver_id, :cookbook_url, :os, :internet_accessible, :subnet_id
  json.url instance_url(instance, format: :json)
end
