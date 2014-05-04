json.array!(@instance_groups) do |instance_group|
  json.extract! instance_group, :id, :group_id, :instance_id, :administrator
  json.url instance_group_url(instance_group, format: :json)
end
