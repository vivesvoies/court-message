# This class create a dummy provider testing purpose.
class DummyProvider
  def send(from:, to:, content:)
    # Do nothing and return a dummy, successful result
    OpenStruct.new(
      message_uuid: SecureRandom.uuid,
      http_response: Net::HTTPAccepted.new("1.1", "202", "Accepted")
    )
  end
end
