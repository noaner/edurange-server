class NavigationPolicy < Struct.new(:user, :navigation)
  def scenarios?
    user.can?(:create_scenario) || !user.scenarios.empty?
  end
end
