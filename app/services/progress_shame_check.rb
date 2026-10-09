# Code-side guard on AI output (not trusted to the model): openers never say, or hint, that anyone is behind.
#
# BookClubFever's no-shame rule: progress is optional, the club temperature names who has finished and never who has
# not, and nothing the software writes tells a reader they are behind, slow or late. Production enforces it in the
# templates' voice ("Never say, or hint, that anyone is behind, slow or late with their reading. Never ask who has
# finished or how far anyone got."). This check enforces the same rule on the demo's output.
#
# The phrases are about a reader's progress, not the plot: "fallen behind", "behind on the reading", "catch up on
# the book", "slow readers", "who has finished", "anyone who hasn't finished", "how far along". Plot language such as
# "the man behind the letters", "caught up in the scandal" or "does he catch up with the creature" does not match. It is a heuristic that errs toward
# blocking; a blocked answer shows the host a plain reason and a Retry button.
class ProgressShameCheck
  READERS = /(?:you|y'all|anyone|anybody|everyone|everybody|someone|somebody|those|people|readers|members|others|folks)/i
  READING = /(?:the\s+|your\s+|their\s+|this\s+|our\s+)?(?:reading|book|chapters?|pages|schedule)/i

  PATTERNS = [
    /\b(?:fall|falls|fallen|falling|fell|lag|lags|lagging)\s+behind\b/i,
    /\bbehind\s+(?:on|with|in)\s+#{READING}\b/i,
    /\bbehind\s+schedule\b/i,
    /\b(?:is|are|'re|was|were)\s+(?:a\s+(?:bit|little)\s+|still\s+|way\s+)?behind\s*(?:[,.;:!?]|\z)/i,
    /\b(?:catch|catches|catching)\s+up(?:\s+(?:on|with)\s+(?:the\s+)?(?:reading|book|chapters?|pages|rest|everyone|others|group|club)\b|\s*(?:[,.;:!?]|\z))/i,
    /\bkeep(?:s|ing)?\s+up\s+with\s+(?:the\s+)?(?:reading|chapters?|pages|club|group|rest|others|everyone|schedule|pace)\b/i,
    /\bslow(?:er|est)?\s+readers?\b/i,
    /\b(?:who|whoever)\s+(?:has|have|hasn't|haven't|has\s+not|have\s+not|already|actually)\s+(?:yet\s+)?(?:finished|completed)\b/i,
    /\b#{READERS}\s+(?:who|that)\s+(?:has|have|hasn't|haven't|has\s+not|have\s+not|didn't|did\s+not|already)\s+(?:yet\s+)?(?:finished|completed|read\s+(?:it|ahead|that\s+far|to\s+the\s+end))\b/i,
    /\b#{READERS}\s+(?:who\s+)?(?:haven't|have\s+not|hasn't|has\s+not|didn't|did\s+not)\s+(?:yet\s+)?(?:finished|reached|got(?:ten)?\s+to|made\s+it)\b/i,
    /\b(?:did|have|has)\s+#{READERS}\s+(?:all\s+)?(?:finish|finished|read\s+it\s+all|get\s+to\s+the\s+end|got\s+to\s+the\s+end)\b/i,
    /\bhow\s+far\s+(?:along|in\b|into\s+(?:the|this)\s+book|(?:has|have|did|is|are)\s+#{READERS}\s+(?:got|gotten|read|come|made\s+it))/i,
    /\bnot\s+(?:yet\s+)?(?:done|finished)\s+(?:with\s+)?#{READING}\b/i
  ].freeze

  # The offending phrases found in `text` (empty when clean).
  def self.found_in(text)
    text = text.to_s
    PATTERNS.filter_map { |pattern| text[pattern]&.strip&.sub(/[,.;:!?]\z/, "") }.uniq
  end

  def self.clean?(text)
    found_in(text).empty?
  end
end
