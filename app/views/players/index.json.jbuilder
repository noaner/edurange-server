json.array!(@players) do |player|
  json.extract! player, :id, :login, :password, :group_id
  json.url player_url(player, format: :json)
end
