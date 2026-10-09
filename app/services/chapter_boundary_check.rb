# Code-side guard on AI output (not trusted to the model): when the club has read only up to a chapter, the openers
# must not reach past it.
#
# BookClubFever's rule is "never spoil the ending or late plot". A model cannot be checked for every spoiler, but it
# can be checked for the plainest one: naming a chapter the club has not reached. This check finds every chapter
# reference in the output ("chapter 14", "chapters 9-12", "Chapter Twelve", "chapters 3, 7 and 11") and reports the
# ones above the club's last chapter, plus references to the end of the book ("the final chapter", "the last
# chapter", "the epilogue"). It is a floor, not a spoiler detector: a plot twist described without a chapter number
# gets through, which is why the prompt, the eval rubric and the adversarial eval case cover the rest.
class ChapterBoundaryCheck
  NUMBER_WORDS = %w[
    zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen
    eighteen nineteen twenty
  ].each_with_index.to_h.merge(
    "thirty" => 30, "forty" => 40, "fifty" => 50
  ).freeze

  NUMBER    = /\d{1,3}|#{NUMBER_WORDS.keys.sort_by { |w| -w.length }.join('|')}/i
  JOINER    = /\s*(?:-|–|—|,|&|\band\b|\bto\b|\bthrough\b|\bor\b)\s*/i
  REFERENCE = /\bchapters?\s+(#{NUMBER}(?:#{JOINER}#{NUMBER})*)\b/i
  END_OF_BOOK = /\b(?:the\s+)?(?:final|last|closing)\s+chapters?\b|\bepilogue\b/i

  # Chapter references in `text` that reach past `last_chapter`, as strings (empty when the text is clean, or when
  # last_chapter is nil because the club has read the whole book).
  def self.violations(text, last_chapter)
    return [] if last_chapter.nil?

    text = text.to_s
    past = text.scan(REFERENCE).flatten.select do |list|
      list.scan(NUMBER).any? { |n| to_number(n) > last_chapter }
    end
    (past.map { |list| "chapter #{list}" } + text.scan(END_OF_BOOK)).uniq
  end

  def self.clean?(text, last_chapter)
    violations(text, last_chapter).empty?
  end

  def self.to_number(token)
    token.match?(/\A\d+\z/) ? token.to_i : NUMBER_WORDS.fetch(token.downcase)
  end

  private_class_method :to_number
end
