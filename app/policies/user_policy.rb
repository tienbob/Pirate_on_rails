class UserPolicy < ApplicationPolicy
  def destroy?
    user.admin? || user == record
  end
end
