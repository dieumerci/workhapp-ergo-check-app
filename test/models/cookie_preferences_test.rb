require "test_helper"

class CookiePreferencesTest < ActiveSupport::TestCase
  setup do
    @jar = ActionDispatch::TestRequest.create.cookie_jar
    @prefs = CookiePreferences.new(@jar)
  end

  test "starts undecided with nothing remembered" do
    assert_not @prefs.decided?
    assert_not @prefs.preferences_allowed?
    assert_empty @prefs.remembered_filters
  end

  test "accepting stores a signed consent cookie" do
    @prefs.record_consent(preferences: true)

    assert @prefs.decided?
    assert @prefs.preferences_allowed?
    assert_not_equal "true", @jar[CookiePreferences::CONSENT_COOKIE], "consent must not be stored as plain text"
  end

  test "declining is a decision that allows nothing optional" do
    @prefs.record_consent(preferences: false)

    assert @prefs.decided?
    assert_not @prefs.preferences_allowed?
  end

  test "filters are only remembered with consent" do
    @prefs.remember_filters(status: "completed", preset: "30")
    assert_empty @prefs.remembered_filters

    @prefs.record_consent(preferences: true)
    @prefs.remember_filters(status: "completed", preset: "30")

    assert_equal({ status: "completed", preset: "30" }, @prefs.remembered_filters)
  end

  test "declining afterwards deletes the remembered filters" do
    @prefs.record_consent(preferences: true)
    @prefs.remember_filters(status: "archived", preset: "all")

    @prefs.record_consent(preferences: false)

    assert_empty @prefs.remembered_filters
    assert_nil @jar[CookiePreferences::PREFS_COOKIE]
  end

  test "invalid values are never stored" do
    @prefs.record_consent(preferences: true)

    @prefs.remember_filters(status: "comp", preset: "30")
    @prefs.remember_filters(status: "completed", preset: "365")

    assert_empty @prefs.remembered_filters
  end

  test "a forged preferences cookie is ignored" do
    @prefs.record_consent(preferences: true)
    @jar[CookiePreferences::PREFS_COOKIE] = { status: "completed", preset: "30" }.to_json

    assert_empty @prefs.remembered_filters
  end

  test "a forged consent cookie counts as no decision" do
    @jar[CookiePreferences::CONSENT_COOKIE] = { v: 1, preferences: true }.to_json

    assert_not @prefs.decided?
    assert_not @prefs.preferences_allowed?
  end
end
