json.array!(@scenarios) do |scenario|
  json.extract! scenario, :id, :game_type, :name
  json.url scenario_url(scenario, format: :json)
end
