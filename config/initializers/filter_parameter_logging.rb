# Be sure to restart your server when you modify this file.

# Parameters matching these names (partial, case-insensitive) are replaced with
# [FILTERED] in request logs, SQL bind logs and exception reports.
# See the ActiveSupport::ParameterFilter documentation for supported notations.
#
# This app handles health data, so the list is deliberately broad:
#   :email, :employee_email   personal identifiers (employee_email is also caught by :email)
#   :responses, :answers      raw assessment answers (matches responses_json and friends)
#   :free_text                free-text answers
#   :captcha                  the sign-in verification code
#   passw/secret/token/...    the Rails defaults
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :captcha, :employee_email, :employee_name, :responses, :answers, :free_text
]
