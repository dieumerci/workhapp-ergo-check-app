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
  inertia_share status_options: -> {
    Status::CANONICAL.map { |value| { value: value, label: Status.label(value), scored: Status.scored?(value) } }
  }
  inertia_share score_sections: -> { ScoreCalculator::SECTIONS.map { |key, label| { key: key, label: label } } }
  inertia_share export_columns: -> { AssessmentExports::Builder::COLUMNS }

  inertia_share ops_pages: -> { Rails.configuration.x.ops_pages }

  # Whether the optional assistant is on, and who would see a question.
  inertia_share assistant: -> { Assistant.public_info }

  # Marks a controller as an internal ops page: 404 unless SHOW_OPS_PAGES is on.
  def self.ops_only
    before_action { head :not_found unless Rails.configuration.x.ops_pages }
  end

  inertia_share auth: -> {
    {
      admin: Current.admin && { name: Current.admin.name, initials: Current.admin.initials },
      company: Current.company && { name: Current.company.name }
    }
  }

  private

  def exports_payload
    return [] unless Current.company

    Current.company.assessment_exports.with_attached_file.includes(:admin).recent.limit(20).map do |export|
      # link_path is on every row, whatever its state: it is the export's own address, and it only ever works for
      # admins of the company that owns it (anyone else gets a 404). download_path is set only while there is a file to fetch.
      export.to_view.merge(
        link_path: download_export_path(export),
        download_path: export.downloadable? ? download_export_path(export) : nil
      )
    end
  end
end
