# frozen_string_literal: true

class InertiaController < ApplicationController
  # Shared with every Inertia response. Only what the shell needs to render:
  # the visitor's cookie choice, who is signed in and which company they see.
  inertia_share cookie_consent: -> {
    { decided: cookie_preferences.decided?, preferences: cookie_preferences.preferences_allowed? }
  }

  inertia_share auth: -> {
    {
      admin: Current.admin && { name: Current.admin.name, initials: Current.admin.initials },
      company: Current.company && { name: Current.company.name }
    }
  }
end
