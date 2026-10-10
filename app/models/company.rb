class Company < ApplicationRecord
  has_many :admins, dependent: :restrict_with_exception
  has_many :employees, dependent: :restrict_with_exception
  has_many :assessments, dependent: :restrict_with_exception
  has_many :assessment_exports, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true
end
