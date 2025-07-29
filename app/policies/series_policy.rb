class SeriesPolicy < ApplicationPolicy
  def update?
    user.admin?
  end

  def show?
    return true if user.admin? || user.pro?
    # Free users can only view non-pro series
    user.free? && !record.is_pro
  end
  
  def create?
    user.admin?
  end

  def destroy?
    user.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin? || user.pro?
        scope.all
      elsif user.free?
        # Free users: only non-pro movies
        scope.where(is_pro: false)
      else
        scope.none
      end
    end
  end
end
