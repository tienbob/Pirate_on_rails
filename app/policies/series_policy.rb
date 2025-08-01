class SeriesPolicy < ApplicationPolicy
  def update?
    user.admin?
  end

  def show?
    return true if user.admin? || user.pro?
    # Free users can view all series (no is_pro restriction)
    user.free?
  end
  
  def create?
    user.admin?
  end

  def destroy?
    user.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin? || user.pro? || user.free?
        scope.all
      else
        scope.none
      end
    end
  end
end
