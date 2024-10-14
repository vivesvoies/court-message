# This class create a dummy provider testing purpose.
class DummyProvider
  def send(from:, to:, content:, success: true)
    OpenStruct.new(message_uuid: SecureRandom.uuid)
  end
end
