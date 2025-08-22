class User < ApplicationRecord
  after_initialize :set_default_role, if: :new_record?

  def set_default_role
    self.role ||= 'free'
  end

  devise :database_authenticatable, :registerable, :recoverable, 
         :rememberable, :validatable, :timeoutable, :confirmable

  has_many :payments, dependent: :destroy
  has_many :movies, dependent: :destroy
  has_many :chats, dependent: :destroy
  has_many :view_analytics, dependent: :destroy

  validates :name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :role, presence: true, inclusion: { in: %w[free pro admin] }
  validates :password, presence: true, length: { minimum: 6 }, on: :create

  # Scopes for better querying
  scope :active, -> { where('last_seen_at > ?', 30.days.ago) }
  scope :pro_users, -> { where(role: 'pro') }
  scope :free_users, -> { where(role: 'free') }
  scope :admins, -> { where(role: 'admin') }
  scope :recent, -> { order(created_at: :desc) }

  def admin?
    role == "admin"
  end

  def pro?
    role == "pro"
  end

  def free?
    role == "free"
  end

  # Activity tracking
  def active?
    last_seen_at && last_seen_at > 30.days.ago
  end

  def total_watch_time
    view_analytics.sum(:watch_duration) || 0
  end

  def favorite_genres
    ViewAnalytic.joins(movie: :tags)
                .where(user: self)
                .group('tags.name')
                .order('COUNT(*) DESC')
                .limit(5)
                .pluck('tags.name')
  end

  # Payment methods
  def has_active_subscription?
    payments.completed.exists? && pro?
  end

  def latest_payment
    payments.order(created_at: :desc).first
  end

  def upgrade_to_pro!
    ActiveRecord::Base.transaction do
      update!(role: 'pro')
      PaymentEvent.log_event(
        latest_payment, 
        'user_upgraded', 
        { previous_role: 'free', new_role: 'pro' }
      ) if latest_payment
    end
  end

  def downgrade_to_free!
    ActiveRecord::Base.transaction do
      update!(role: 'free')
      PaymentEvent.log_event(
        latest_payment, 
        'user_downgraded', 
        { previous_role: 'pro', new_role: 'free' }
      ) if latest_payment
    end
  end

  def after_confirmation
    UserMailer.welcome_email(self).deliver_later
  end
end
