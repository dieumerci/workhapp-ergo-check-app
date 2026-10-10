# frozen_string_literal: true

class InertiaController < ApplicationController
  # Shared with every Inertia response. Only what the shell needs to render:
  # who is signed in and which company they are looking at.
  inertia_share auth: -> {
    {
      admin: Current.admin && { name: Current.admin.name, initials: Current.admin.initials },
      company: Current.company && { name: Current.company.name }
    }
  }
end
