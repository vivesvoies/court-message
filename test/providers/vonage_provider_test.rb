require "test_helper"

class VonageProviderTest < ActiveSupport::TestCase
  test "reports network failures as a failed send instead of raising" do
    [ Net::OpenTimeout.new, Net::ReadTimeout.new, SocketError.new("getaddrinfo failed"),
      Errno::ECONNRESET.new, OpenSSL::SSL::SSLError.new("handshake failed") ].each do |error|
      result = provider_raising(error).send(from: "+33644635900", to: "+33611111111", content: "Bonjour")

      assert_not(result.success?, error.class.name)
      assert_match(error.class.name, result.error)
    end
  end

  private

  def provider_raising(error)
    messaging = Object.new
    messaging.define_singleton_method(:send) { |**| raise error }
    client = Struct.new(:messaging).new(messaging)

    Vonage::Client.stub(:new, client) { VonageProvider.new }
  end
end
