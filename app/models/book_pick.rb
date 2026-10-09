class BookPick < ApplicationRecord
  belongs_to :user
  has_many :conversation_sets, dependent: :destroy
  has_one :latest_conversation_set,
          -> { order(generated_at: :desc, created_at: :desc) },
          class_name: "ConversationSet"

  READ_THROUGHS = %w[whole_book up_to_chapter].freeze
  CLUB_VIBES    = %w[casual deep_dive mixed].freeze

  # Form labels.
  READ_THROUGH_LABELS = {
    "whole_book"    => "The whole book",
    "up_to_chapter" => "Up to a chapter"
  }.freeze

  CLUB_VIBE_LABELS = {
    "casual"    => "Casual: a friendly evening, first-timers welcome",
    "deep_dive" => "Deep dive: the club likes to dig in and argue",
    "mixed"     => "Mixed: some of each"
  }.freeze

  # The phrase the AI template receives as {{club_vibe}}.
  CLUB_VIBE_PROMPTS = {
    "casual"    => "casual: a friendly evening, maybe people's first book club, so keep the openers gentle and open",
    "deep_dive" => "deep dive: a club that has met before and likes to dig in and disagree",
    "mixed"     => "mixed: some members want to dig in and some are here for a friendly evening"
  }.freeze

  before_validation :clear_chapter_for_whole_book

  validates :title,        presence: true, length: { maximum: 200 }
  validates :author,       presence: true, length: { maximum: 120 }
  validates :read_through, presence: true, inclusion: { in: READ_THROUGHS }
  validates :chapter,      presence: true, numericality: { only_integer: true, in: 1..500 }, if: :up_to_chapter?
  validates :club_vibe,    presence: true, inclusion: { in: CLUB_VIBES }
  validates :reader_notes, length: { maximum: 1500 }

  def up_to_chapter? = read_through == "up_to_chapter"

  # The last chapter the club has read, or nil when it has read the whole book.
  def last_chapter
    chapter if up_to_chapter?
  end

  def read_through_label
    up_to_chapter? ? "Up to the end of chapter #{chapter}" : "The whole book"
  end

  def club_vibe_label
    CLUB_VIBE_LABELS.fetch(club_vibe, club_vibe.to_s.humanize).split(":").first
  end

  # Variables for the bookclubfever_openers_v1 template. Nothing about the member is sent.
  def ai_variables
    {
      title:        title,
      author:       author,
      read_through: read_through_prompt,
      club_vibe:    CLUB_VIBE_PROMPTS.fetch(club_vibe),
      reader_notes: reader_notes.presence || "None"
    }
  end

  private

  def read_through_prompt
    if up_to_chapter?
      "up to the end of chapter #{chapter}. Nothing after chapter #{chapter} may be mentioned, hinted at, or foreshadowed, " \
        "and no chapter number above #{chapter} may appear."
    else
      "the whole book. Everyone at this meeting has had the chance to finish it, so the ending may be discussed."
    end
  end

  def clear_chapter_for_whole_book
    self.chapter = nil if read_through == "whole_book"
  end
end
