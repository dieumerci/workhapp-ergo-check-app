# frozen_string_literal: true

class InertiaController < ApplicationController
  # Shared with every Inertia response. Only what the shell needs to render:
  # the visitor's cookie choice, who is signed in and which company they see.
  inertia_share cookie_consent: -> {
    { decided: cookie_preferences.decided?, preferences: cookie_preferences.preferences_allowed? }
  }

  # The company's recent exports. A lambda, so the export page's polling can
  # reload just this prop; it is also what drives the "Exports" menu badge.
  inertia_share exports: -> { exports_payload }

  # Single server-side definitions the UI renders from (filters, drawer, export dialog).
  inertia_share status_options: -> { Status::CANONICAL.map { |value| { value: value, label: Status.label(value) } } }
  inertia_share export_columns: -> { AssessmentExports::Builder::COLUMNS }

  inertia_share auth: -> {
    {
      admin: Current.admin && { name: Current.admin.name, initials: Current.admin.initials },
      company: Current.company && { name: Current.company.name }
    }
  }

  private

  def exports_payload
    return [] unless Current.company

    Current.company.assessment_exports.with_attached_file.recent.limit(20).map do |export|
      export.to_view.merge(download_path: export.downloadable? ? download_export_path(export) : nil)
    end
  end
end
