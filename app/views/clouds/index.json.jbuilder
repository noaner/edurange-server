json.array!(@clouds) do |cloud|
  json.extract! cloud, :id, :name, :cidr_block, :driver_id, :scenario_id
  json.url cloud_url(cloud, format: :json)
end
