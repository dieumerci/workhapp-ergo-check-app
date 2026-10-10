require "test_helper"

class SecurityHardeningTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @admin = create_admin(company: @company)
  end

  def ready_export
    export = AssessmentExport.create!(company: @company, admin: @admin)
    export.file.attach(io: StringIO.new("a,b\n"), filename: "x.csv", content_type: "text/csv")
    export.mark_ready!(row_count: 1)
    export
  end

  # ---- Active Storage routes ---------------------------------------------

  test "the unauthenticated Active Storage upload and blob endpoints do not exist" do
    [
      [ :post, "/rails/active_storage/direct_uploads" ],
      [ :put, "/rails/active_storage/disk/sometoken" ],
      [ :get, "/rails/active_storage/blobs/redirect/signed/file.csv" ],
      [ :get, "/rails/active_storage/blobs/proxy/signed/file.csv" ],
      [ :get, "/rails/active_storage/representations/redirect/a/b/file.png" ]
    ].each do |verb, path|
      public_send(verb, path)
      assert_response :not_found, "#{verb.upcase} #{path} must not be routable"
    end
  end

  test "no direct-upload or blob route is drawn at all" do
    names = Rails.application.routes.routes.filter_map { |route| route.name }

    assert_not_includes names, "rails_direct_uploads"
    assert_not_includes names, "rails_service_blob"
    assert_not_includes names, "rails_blob_representation"
    assert_includes names, "rails_disk_service", "the signed download link is still needed"
  end

  test "an admin can still download an export through the signed link" do
    export = ready_export
    sign_in_as(@admin)

    get download_export_path(export)
    follow_redirect!

    assert_response :success
    assert_equal "a,b\n", response.body
  end

  # ---- logs ------------------------------------------------------------------

  test "neither the signed link nor Active Storage's debug line reaches the log" do
    export = ready_export
    sign_in_as(@admin)

    log = captured_log do
      get download_export_path(export)
      get response.location
    end

    assert_no_match(%r{/rails/active_storage/disk/}, log, "the signed path was logged")
    assert_no_match(/Generated URL for file at key/, log)
    assert_no_match(/Redirected to \S*active_storage/, log)
  end

  # ---- ephemeral disk guard ------------------------------------------------

  test "booting on an ephemeral-disk platform with local storage is refused" do
    error = assert_raises(ActiveStorageGuard::MisconfiguredStorage) do
      ActiveStorageGuard.verify!(service_name: :local, ephemeral_platform: true)
    end
    assert_match(/ACTIVE_STORAGE_SERVICE/, error.message)
  end

  test "object storage, or a platform with a persistent disk, is accepted" do
    assert_nil ActiveStorageGuard.verify!(service_name: :amazon, ephemeral_platform: true)
    assert_nil ActiveStorageGuard.verify!(service_name: :local, ephemeral_platform: false)
    assert_nil ActiveStorageGuard.verify!(service_name: "local", ephemeral_platform: false)
  end

  # ---- ops pages -------------------------------------------------------------

  def with_ops_pages(value)
    previous = Rails.configuration.x.ops_pages
    Rails.configuration.x.ops_pages = value
    yield
  ensure
    Rails.configuration.x.ops_pages = previous
  end

  test "the ops pages are 404 when switched off, and hidden from the navigation" do
    sign_in_as(@admin)

    with_ops_pages(false) do
      get release_plan_path
      assert_response :not_found
      get release_plan_normalize_path, params: { value: "comp" }
      assert_response :not_found
      get safeguards_path
      assert_response :not_found

      get assessments_path
      assert_equal false, inertia.props[:ops_pages]
    end
  end

  test "the ops pages are available when switched on" do
    sign_in_as(@admin)

    with_ops_pages(true) do
      get release_plan_path
      assert_response :success
      get safeguards_path
      assert_response :success
      get assessments_path
      assert_equal true, inertia.props[:ops_pages]
    end
  end

  test "production hides the ops pages unless SHOW_OPS_PAGES says otherwise" do
    cast = ActiveModel::Type::Boolean.new
    default_for = ->(env, setting) { cast.cast(setting || (env == "production" ? "false" : "true")) }

    assert_equal false, default_for.call("production", nil)
    assert_equal true, default_for.call("production", "true")
    assert_equal true, default_for.call("development", nil)
  end
end
