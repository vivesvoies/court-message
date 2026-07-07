# Submits an outbound message to the provider, retrying with backoff when the
# provider refuses it. The message stays "unsent" while retries are pending
# and becomes "failed" once retries are exhausted.
class MessageDeliveryJob < ApplicationJob
  queue_as :default

  # The message was deleted before the job ran.
  discard_on ActiveJob::DeserializationError

  retry_on OutboundMessagesService::DeliveryError, wait: :polynomially_longer, attempts: 5 do |job, error|
    message = job.arguments.first
    message.update!(status: :failed)
    Sentry.capture_exception(error)
  end

  def perform(message)
    return unless message.unsent_status?

    OutboundMessagesService.new(message).submit!
  end
end
