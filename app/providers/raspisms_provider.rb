class RaspiSMSProvider
  require 'net/http'
  require 'uri'
  require 'json'

  # BASE_URL = Rails.application.credentials.dig(:raspisms, :base_url)
  # API_KEY = Rails.application.credentials.dig(:raspisms, :api_key)
  BASE_URL = "http://192.168.1.2/api/send-sms/"
  API_KEY = "faa9845d784d6d822fa1d6d579500207"

  def initialize
  end

  def send(from:, to:, content:)
    # uri = URI("http://192.168.1.28/api/send-sms/")
    url = URI("https://raspisms.fr/api/send-sms/?api_key=faa9845d784d6d822fa1d6d579500207")
    # params = {
    #   # api_key: "faa9845d784d6d822fa1d6d579500207",
    #   text: content,
    #   to: to
    # }
    # url.query = URI.encode_www_form(params)

    # response = Net::HTTP.get_response(uri)
    # parse_response(response)


    # url = URI("https://raspisms.fr/api/send-sms/?api_key=faa9845d784d6d822fa1d6d579500207")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url)
    response = http.request(request)
    puts response.read_body
    parse_response(response)

    # GET
    # text (str)
    # to (str), optional
    # id_phone (str), optional
  end

  private

  def parse_response(response)
    json_response = JSON.parse(response.body)

    if json_response["error"] == 0
      OpenStruct.new(
        http_response: response,
        message_uuid: json_response["response"]
      )
    else
      OpenStruct.new(
        http_response: response,
        error_message: json_response["message"]
      )
    end
  rescue JSON::ParserError
    OpenStruct.new(http_response: response, error_message: "Invalid JSON response")
  end
end
