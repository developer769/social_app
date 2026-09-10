require "net/http"
require "json"

module SocialProvider
  # The one way this application talks to a social platform.
  #
  # Every provider gets the same timeouts, the same redirect policy, and the
  # same translation from HTTP status to our two error kinds -- so a caller
  # never has to know whether Meta says "error.code" and TikTok says
  # "error.code" in a different place (spec 30).
  #
  # The retry decision lives in the error class, not here: TransientError means
  # the job may reschedule, PermanentError means it must not. Retrying a
  # permanent failure burns quota and gets apps flagged.
  class HttpClient
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 20

    # 429 and 5xx are the platform asking us to come back later. Everything
    # else in the 4xx range is us being wrong, and will still be wrong on a
    # retry.
    TRANSIENT_STATUSES = [ 408, 425, 429, 500, 502, 503, 504 ].freeze

    def initialize(provider:)
      @provider = provider.to_s
    end

    def get(url, headers: {}, params: {})
      uri = URI(url)
      uri.query = URI.encode_www_form(params) if params.present?
      request(Net::HTTP::Get.new(uri), uri, headers)
    end

    def post_form(url, form:, headers: {})
      uri = URI(url)
      req = Net::HTTP::Post.new(uri)
      req.set_form_data(form)
      request(req, uri, headers)
    end

    def post_json(url, body:, headers: {})
      uri = URI(url)
      req = Net::HTTP::Post.new(uri)
      req["content-type"] = "application/json"
      req.body = JSON.generate(body)
      request(req, uri, headers)
    end

    private

    def request(req, uri, headers)
      headers.each { |k, v| req[k.to_s] = v }
      req["accept"] = "application/json"
      req["user-agent"] = "Prachar/1.0"

      response = Net::HTTP.start(
        uri.hostname, uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      ) { |http| http.request(req) }

      handle(response)
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise TransientError.new("#{@provider} did not respond in time.", code: "timeout")
    rescue SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH => e
      raise TransientError.new("Could not reach #{@provider}.", code: e.class.name.demodulize.underscore)
    rescue OpenSSL::SSL::SSLError
      # Not retried: a TLS failure against a major platform is a configuration
      # or interception problem, and hammering it will not fix either.
      raise PermanentError.new("Could not establish a secure connection to #{@provider}.", code: "ssl_error")
    end

    def handle(response)
      status = response.code.to_i
      body = parse(response.body)

      return body if status.between?(200, 299)

      message = extract_message(body) || "#{@provider} returned #{status}."

      if TRANSIENT_STATUSES.include?(status)
        raise TransientError.new(message, code: status.to_s, retry_after: retry_after(response))
      end

      raise PermanentError.new(message, code: status.to_s)
    end

    def parse(raw)
      return {} if raw.blank?

      JSON.parse(raw)
    rescue JSON::ParserError
      # Some providers return HTML on an outage. Keeping the raw body out of
      # the error avoids pasting a login page into a customer-facing message.
      { "raw" => raw.to_s.truncate(200) }
    end

    # Every platform buries its message somewhere different; this is the union
    # of the shapes they use, so callers get a sentence rather than a status.
    def extract_message(body)
      return nil unless body.is_a?(Hash)

      body.dig("error", "message") ||
        body.dig("error", "error_user_msg") ||
        body["error_description"] ||
        body["message"] ||
        (body["error"].is_a?(String) ? body["error"] : nil)
    end

    def retry_after(response)
      value = response["retry-after"] || response["x-ratelimit-reset"]
      return nil if value.blank?

      seconds = value.to_i
      seconds.positive? ? seconds.seconds : nil
    end
  end
end
