class User < ApplicationRecord
  after_initialize :set_default_role, if: :new_record?

  def set_default_role
    self.role ||= 'free'
  end
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  has_many :payments
  has_many :movies

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :role, presence: true
  validates :password, presence: true, length: { minimum: 6 }

  def admin?
    role == "admin"
  end

  def pro?
    role == "pro"
  end

  def free?
    role == "free"
  end
end
