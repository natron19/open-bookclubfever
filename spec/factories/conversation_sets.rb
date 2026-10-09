FactoryBot.define do
  factory :conversation_set do
    association :book_pick
    status       { "pending" }
    generated_at { nil }
    gemini_raw   { nil }

    trait :completed do
      status            { "completed" }
      generated_at      { Time.current }
      gemini_raw        { "{}" }
      book_familiarity  { "known" }
      spoiler_boundary  { "Stays within chapters 1 to 10." }
      openers do
        [
          { "question" => "Victor runs from the creature the night he makes it; what would you have done?", "angle" => "character",
            "why_it_works" => "Everyone remembers the scene.", "follow_up" => "Is running away human?" },
          { "question" => "Is Victor hard to like on purpose?", "angle" => "disagreement",
            "why_it_works" => "The room will split.", "follow_up" => "Do we need someone to root for?" },
          { "question" => "Why tell it through Walton's letters?", "angle" => "craft",
            "why_it_works" => "It gets people looking at how the book is built.", "follow_up" => "Did you trust Victor more or less?" },
          { "question" => "Is Victor's silence at the trial the scariest thing so far?", "angle" => "theme",
            "why_it_works" => "Moves the talk to responsibility.", "follow_up" => "What would speaking have cost him?" },
          { "question" => "Have you ever kept a project to yourself until it felt too big to share?", "angle" => "personal",
            "why_it_works" => "Anyone can answer it.", "follow_up" => "What made you tell someone?" }
        ]
      end
      spoiler_free_line { "Chapter 10 ends on a glacier with a conversation you will want to talk about." }
      next_reads do
        [
          { "title" => "Strange Case of Dr Jekyll and Mr Hyde", "author" => "Robert Louis Stevenson", "tie_in" => "Another maker who cannot face what he made." },
          { "title" => "The Island of Doctor Moreau", "author" => "H. G. Wells", "tie_in" => "What does a maker owe his creatures?" },
          { "title" => "Dracula", "author" => "Bram Stoker", "tie_in" => "Also told in letters and journals." }
        ]
      end
    end

    trait :unsure do
      completed
      book_familiarity { "unsure" }
    end

    trait :failed do
      status         { "failed" }
      generated_at   { Time.current }
      gemini_raw     { "malformed response" }
      failure_reason { "JSON parse failed: unexpected token" }
    end
  end
end
