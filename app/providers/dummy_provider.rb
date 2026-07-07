# This class create a dummy provider testing purpose.
class DummyProvider
  def send(from:, to:, content:)
    # Do nothing and return a dummy result
    ProviderResult.new(success: true, message_uuid: SecureRandom.uuid)
  end
end
