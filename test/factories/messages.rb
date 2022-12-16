FactoryBot.define do
  factory :message do
    sender { create(:contact) }
    conversation { sender.build_conversation }
    content { Faker::TvShows::BojackHorseman.tongue_twister }
  end
end
