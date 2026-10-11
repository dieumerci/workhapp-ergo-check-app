require "test_helper"
require "uri"

# The S3 path is how exports are stored on a platform whose disk disappears (Heroku, a container
# without a volume). There are no real AWS credentials here, so nothing is sent over the network:
# the AWS SDK's own stubbed client answers the calls, and the signed links are generated for real,
# because signing needs only the key and the clock. What this proves is that config/storage.yml
# reads the AWS_* variables, that an export is written through the S3 service and not the local
# disk, and that the download link is a signed, one-minute, attachment link on the right bucket.
# What it cannot prove is a round trip to a real bucket: do one export after configuring one.
class S3StorageTest < ActiveSupport::TestCase
  AWS_ENV = {
    "AWS_S3_BUCKET" => "example-exports", "AWS_ACCESS_KEY_ID" => "AKIAEXAMPLE", "AWS_SECRET_ACCESS_KEY" => "example-secret-key",
    "AWS_REGION" => "eu-west-1"
  }.freeze

  setup do
    @previous_env = AWS_ENV.keys.index_with { |key| ENV[key] }
    AWS_ENV.each { |key, value| ENV[key] = value }
    @previous_services = ActiveStorage::Blob.services
    @previous_service = ActiveStorage::Blob.service
    @s3 = register_stubbed_service
  end

  teardown do
    ActiveStorage::Blob.services = @previous_services
    ActiveStorage::Blob.service = @previous_service
    @previous_env.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
  end

  test "the amazon service is configured from the AWS_* variables and keeps its files private" do
    assert_instance_of ActiveStorage::Service::S3Service, @s3
    assert_equal "example-exports", @s3.bucket.name
    assert_equal "eu-west-1", @s3.client.client.config.region
    assert_not @s3.public?, "exports must never be publicly readable"
  end

  test "a download link is signed, lasts one minute, is an attachment and points at the bucket" do
    url = URI.parse(@s3.url("some-key", expires_in: 1.minute, filename: ActiveStorage::Filename.new("assessments.csv"),
                                         content_type: "text/csv", disposition: :attachment))
    query = URI.decode_www_form(url.query).to_h

    assert_match(/\Aexample-exports\.s3\.eu-west-1\.amazonaws\.com\z/, url.host)
    assert_equal "60", query["X-Amz-Expires"]
    assert query["X-Amz-Signature"].present?, "the link must be signed"
    assert_match(/\Aattachment/, query["response-content-disposition"])
  end

  test "an export is written through S3 and handed out as a signed link" do
    company = create_company
    admin = create_admin(company: company)
    create_legacy_assessment(company: company, status: "completed", responses: sections_json(80, 70, 75, 75))
    export = AssessmentExport.create!(company: company, admin: admin)

    export.claim!
    AssessmentExports::Builder.new(export).call

    assert export.reload.ready?
    assert export.file.attached?
    assert_equal "example-exports", export.file.service.bucket.name, "the file should live in the S3 bucket, not on the local disk"
    link = URI.parse(export.download_url)
    assert_equal "example-exports.s3.eu-west-1.amazonaws.com", link.host
    assert_equal "60", URI.decode_www_form(link.query).to_h["X-Amz-Expires"]
  end

  private

  # The same definition production uses (config/storage.yml), read with the AWS_* variables set,
  # but with the SDK's stubbed client so no request leaves the machine. Active Storage finds a blob's
  # service by name in its registry, so the stubbed one is registered there and made the default;
  # otherwise an upload would build a second, real client from the same file.
  def register_stubbed_service
    definition = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/storage.yml")).fetch("amazon").symbolize_keys
    registry = ActiveStorage::Service::Registry.new(s3_stubbed: definition.merge(stub_responses: true))
    ActiveStorage::Blob.services = registry
    registry.fetch(:s3_stubbed).tap { |service| ActiveStorage::Blob.service = service }
  end
end
