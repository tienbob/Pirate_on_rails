class MoviePolicy < ApplicationPolicy
  # NOTE: Up to Pundit v2.3.1, the inheritance was declared as
  # `Scope < Scope` rather than `Scope < ApplicationPolicy::Scope`.
  # In most cases the behavior will be identical, but if updating existing
  # code, beware of possible changes to the ancestors:
  # https://gist.github.com/Burgestrand/4b4bc22f31c8a95c425fc0e30d7ef1f5
  def update?
    user.admin?
  end

  def show?
    return true if user.admin? || user.pro?
    # Free users can only view non-pro movies
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
        # Free users: non-pro movies OR pro movies older than 3 months
        scope.where("is_pro = ? OR (is_pro = ? AND release_date <= ?)", false, true, 3.months.ago)
      else
        scope.none
      end
    end
  end
end
