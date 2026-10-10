class Employee < ApplicationRecord
  belongs_to :company
  has_many :assessments, dependent: :restrict_with_exception

  # Names and e-mail addresses are personal data: keep them out of `inspect`,
  # console output, error pages and SQL bind logging.
  self.filter_attributes += %i[name email]

  validates :name, presence: true
end
