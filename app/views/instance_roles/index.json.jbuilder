json.array!(@instance_roles) do |instance_role|
  json.extract! instance_role, :id, :instance_id, :role_id
  json.url instance_role_url(instance_role, format: :json)
end
