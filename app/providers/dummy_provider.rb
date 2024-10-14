# This class create a dummy provider testing purpose.
class DummyProvider
  def initialize(success: true, error_code: nil)
    @success = success
    @error_code = error_code
  end

  def send(from:, to:, content:)
    if @success
      OpenStruct.new(
        message_uuid: SecureRandom.uuid,
        http_response: Net::HTTPSuccess.new(1.0, '200', 'OK')
      )
    else
      error_response = case @error_code
                       when 400
                         Net::HTTPBadRequest.new(1.0, '400', 'Bad Request')
                       when 403
                         Net::HTTPForbidden.new(1.0, '403', 'Forbidden')
                       else
                         Net::HTTPServerError.new(1.0, '500', 'Internal Server Error')
                       end

      OpenStruct.new(
        message_uuid: SecureRandom.uuid,
        http_response: error_response
      )
    end
  end
end
