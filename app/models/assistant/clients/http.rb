require "net/http"
require "json"

# The one place the assistant talks to the network. Short timeouts, no retries,
# and no request or response body is ever put in an error message or a log:
# the question can hold anything a person typed.
module Assistant::Clients::Http
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 20

  FRIENDLY = {
    401 => "The assistant's API key was rejected. Check the key on the server.",
    403 => "The assistant's API key is not allowed to do this.",
    429 => "The assistant is busy right now. Try again in a moment."
  }.freeze

  # Sends +body+ as JSON to +url+ and returns the parsed JSON, or raises Unavailable.
  # +transport+ exists so tests can stand in for the network.
  def self.post_json(url, headers:, body:, transport: nil)
    status, text = (transport || method(:send_request)).call(URI(url), headers, JSON.generate(body))
    raise Assistant::Unavailable, FRIENDLY.fetch(status, "The assistant is unavailable right now (#{status}).") unless (200..299).cover?(status)

    JSON.parse(text)
  rescue JSON::ParserError
    raise Assistant::Unavailable, "The assistant sent a reply that could not be read."
  rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, Net::OpenTimeout, Net::ReadTimeout, EOFError
    raise Assistant::Unavailable, "The assistant could not be reached."
  end

  def self.send_request(uri, headers, body)
    request = Net::HTTP::Post.new(uri, headers.merge("Content-Type" => "application/json"))
    request.body = body
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.request(request)
    end
    [ response.code.to_i, response.body.to_s ]
  end
end
