class ScenarioPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      user.scenarios
    end
  end

  def create?
    user.can? :create_scenario
  end

  def update?
    user.can? :edit, record
  end

  def show?
    user.can? :view, record
  end

  def destroy?
    user.can? :destroy, record
  end

  def boot?
    user.can? :boot, record
  end

  def unboot?
    user.can? :boot, record
  end
end
