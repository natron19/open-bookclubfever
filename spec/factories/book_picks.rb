FactoryBot.define do
  factory :book_pick do
    association :user
    title        { "Frankenstein" }
    author       { "Mary Shelley" }
    read_through { "up_to_chapter" }
    chapter      { 10 }
    club_vibe    { "mixed" }
    reader_notes { "A few people said Victor is impossible to like." }

    trait :whole_book do
      read_through { "whole_book" }
      chapter      { nil }
    end
  end
end
