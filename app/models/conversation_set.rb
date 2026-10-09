class ConversationSet < ApplicationRecord
  belongs_to :book_pick
  has_one :user, through: :book_pick

  STATUSES      = %w[pending completed failed].freeze
  ANGLES        = %w[theme character craft personal disagreement].freeze
  FAMILIARITIES = %w[known unsure].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :book_familiarity, inclusion: { in: FAMILIARITIES }, allow_nil: true

  def completed? = status == "completed"
  def failed?    = status == "failed"
  def unsure?    = book_familiarity == "unsure"

  # The book pick was edited after these openers were written.
  def stale?
    generated_at.present? && book_pick.updated_at > generated_at
  end

  def to_markdown
    lines = []
    lines << "# Conversation openers: #{book_pick.title}"
    lines << ""
    lines << "_#{book_pick.title} by #{book_pick.author}. #{book_pick.read_through_label}; #{book_pick.club_vibe_label.downcase} club. " \
             "Generated #{generated_at&.strftime('%Y-%m-%d') || 'unknown'} by #{ENV.fetch('APP_NAME', 'BookClubFever Demo')}._"
    lines << ""
    lines << "_AI-generated: a host's starting point, not a reading guide. Check every detail against the book._"
    lines << ""
    if unsure?
      lines << "> The AI did not know this book well, so these openers lean on your notes. Check them against the book."
      lines << ""
    end
    lines << "**Spoiler boundary:** #{spoiler_boundary}"
    lines << ""
    lines << "## Five openers"
    lines << ""
    openers.each_with_index do |opener, i|
      lines << "#{i + 1}. **#{opener['question']}** _(#{opener['angle']})_"
      lines << "   - Why it works: #{opener['why_it_works']}"
      lines << "   - Follow-up: #{opener['follow_up']}"
    end
    lines << ""
    lines << "## A spoiler-free line for the group chat"
    lines << ""
    lines << "> #{spoiler_free_line}"
    lines << ""
    lines << "## If the club liked this, read next"
    lines << ""
    next_reads.each do |pick|
      lines << "- **#{pick['title']}** by #{pick['author']}: #{pick['tie_in']}"
    end
    lines.join("\n") + "\n"
  end

  def markdown_filename
    slug = book_pick.title.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "").presence || "book"
    "#{slug}-openers.md"
  end
end
