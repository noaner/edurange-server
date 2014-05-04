json.array!(@roles) do |role|
  json.extract! role, :id, :name, :packages, :recipes
  json.url role_url(role, format: :json)
end
