# A company admin. The company an admin belongs to is the only tenant they can
# ever see: every controller derives it from the signed-in admin (Current.company),
# never from a request parameter.
class Admin < ApplicationRecord
  belongs_to :company

  has_secure_password
  normalizes :email, with: ->(value) { value.strip.downcase }

  self.filter_attributes += %i[name email password_digest]

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12 }, allow_nil: true

  def initials
    name.to_s.split.first(2).filter_map { |part| part[0]&.upcase }.join
  end
end
