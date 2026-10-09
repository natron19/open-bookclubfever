class ConversationSetsController < ApplicationController
  TEMPLATE = "bookclubfever_openers_v1".freeze

  OPENER_COUNT       = 5
  NEXT_READ_COUNT    = 3
  MIN_ANGLES         = 3
  MAX_QUESTION_CHARS = 160
  LINK               = %r{https?://|\bwww\.}i

  before_action :set_book_pick

  rate_limit to: 10, within: 1.minute, only: :create, by: -> { current_user.id }

  # shared/_ai_error's "Try again" button is a GET to the current path; send it back to the book.
  def index
    redirect_to book_pick_path(@book_pick)
  end

  def show
    @conversation_set = @book_pick.conversation_sets.find(params[:id])
  end

  def create
    raw = GeminiService.generate(template: TEMPLATE, variables: @book_pick.ai_variables)

    @conversation_set = @book_pick.conversation_sets.create!(
      status:       "pending",
      gemini_raw:   raw,
      generated_at: Time.current
    )

    result = parse_openers!(raw)
    @conversation_set.update!(result.merge(status: "completed"))
    redirect_to book_pick_conversation_set_path(@book_pick, @conversation_set)

  rescue ParseError => e
    @conversation_set.update!(status: "failed", failure_reason: e.message.truncate(250), gemini_raw: e.raw)
    redirect_to book_pick_conversation_set_path(@book_pick, @conversation_set)

  rescue GeminiService::BudgetExceededError
    render "shared/ai_error_page", locals: { error_type: :budget_exceeded }, status: :unprocessable_entity

  rescue GeminiService::GatekeeperError
    render "shared/ai_error_page", locals: { error_type: :gatekeeper_blocked }, status: :unprocessable_entity

  rescue GeminiService::OutputGuardError
    render "shared/ai_error_page", locals: { error_type: :output_blocked }, status: :unprocessable_entity

  rescue GeminiService::TimeoutError
    render "shared/ai_error_page", locals: { error_type: :timeout }, status: :unprocessable_entity

  rescue GeminiService::GeminiError
    render "shared/ai_error_page", locals: { error_type: :error }, status: :unprocessable_entity
  end

  private

  def set_book_pick
    @book_pick = current_user.book_picks.find(params[:book_pick_id])
  end

  ParseError = Class.new(StandardError) do
    attr_reader :raw
    def initialize(msg, raw:)
      super(msg)
      @raw = raw
    end
  end

  # Validates the bookclubfever_openers_v1 JSON and returns the ConversationSet attributes.
  # Hard rules enforced here, not trusted to the model: nothing past the club's chapter (ChapterBoundaryCheck),
  # nothing that says or hints anyone is behind (ProgressShameCheck), no links, and no next read that is the
  # book the club is already reading.
  def parse_openers!(raw)
    fail_parse = ->(msg) { raise ParseError.new(msg, raw: raw) }

    stripped = raw.to_s.strip.gsub(/\A```(?:json)?\s*|\s*```\z/, "").strip
    parsed   = JSON.parse(stripped)
    fail_parse.("Expected a JSON object") unless parsed.is_a?(Hash)

    familiarity = parsed["book_familiarity"].to_s.strip.downcase
    unless ConversationSet::FAMILIARITIES.include?(familiarity)
      fail_parse.("book_familiarity must be one of #{ConversationSet::FAMILIARITIES.join(', ')}")
    end

    boundary = text_field(parsed, "spoiler_boundary") || fail_parse.("spoiler_boundary is missing")
    line     = text_field(parsed, "spoiler_free_line") || fail_parse.("spoiler_free_line is missing")

    openers = object_list(parsed["openers"], %w[question angle why_it_works follow_up])
    unless openers&.size == OPENER_COUNT
      fail_parse.("Expected exactly #{OPENER_COUNT} openers with a question, angle, why_it_works and follow_up, " \
                  "got #{Array(parsed['openers']).size}")
    end
    openers.each { |o| o["angle"] = o["angle"].downcase }
    bad_angles = openers.map { |o| o["angle"] } - ConversationSet::ANGLES
    fail_parse.("Unknown opener angle: #{bad_angles.uniq.join(', ')}") if bad_angles.any?
    if openers.map { |o| o["angle"] }.uniq.size < MIN_ANGLES
      fail_parse.("Expected openers from at least #{MIN_ANGLES} different angles")
    end
    if (long = openers.find { |o| o["question"].length > MAX_QUESTION_CHARS })
      fail_parse.("An opener is #{long['question'].length} characters; the limit is #{MAX_QUESTION_CHARS}")
    end

    next_reads = object_list(parsed["next_reads"], %w[title author tie_in])
    unless next_reads&.size == NEXT_READ_COUNT
      fail_parse.("Expected exactly #{NEXT_READ_COUNT} next_reads with a title, author and tie_in, " \
                  "got #{Array(parsed['next_reads']).size}")
    end
    if next_reads.any? { |r| same_title?(r["title"], @book_pick.title) }
      fail_parse.("A next read was the book the club is already reading")
    end

    output_text = [ boundary, line, *openers.flat_map(&:values), *next_reads.flat_map(&:values) ].join("\n")

    fail_parse.("The response contained a link, so it was not shown") if output_text.match?(LINK)

    past = ChapterBoundaryCheck.violations(output_text, @book_pick.last_chapter)
    if past.any?
      fail_parse.("The response mentioned #{past.first}, past the club's chapter #{@book_pick.chapter}, so it was not shown")
    end

    shame = ProgressShameCheck.found_in(output_text)
    if shame.any?
      fail_parse.("The response said or hinted that someone is behind (\"#{shame.first}\"), so it was not shown")
    end

    {
      book_familiarity:  familiarity,
      spoiler_boundary:  boundary,
      openers:           openers,
      spoiler_free_line: line,
      next_reads:        next_reads
    }
  rescue JSON::ParserError => e
    raise ParseError.new("JSON parse failed: #{e.message.truncate(120)}", raw: raw)
  end

  # A non-blank string at `key`, stripped; nil otherwise.
  def text_field(parsed, key)
    value = parsed[key]
    value.strip if value.is_a?(String) && value.strip.present?
  end

  # An array of objects that each have every key as a non-blank string, stripped and limited to those keys;
  # nil when the value is anything else.
  def object_list(value, keys)
    return nil unless value.is_a?(Array)
    return nil unless value.all? { |item| item.is_a?(Hash) && keys.all? { |k| item[k].is_a?(String) && item[k].strip.present? } }
    value.map { |item| keys.index_with { |k| item[k].strip } }
  end

  # "Frankenstein; or, The Modern Prometheus" and "frankenstein" are the same book; the main title decides.
  def same_title?(a, b)
    normalize = ->(t) { t.to_s.split(/[:;(]/).first.to_s.downcase.sub(/\A\s*(the|a|an)\s+/, "").gsub(/[^a-z0-9]+/, "") }
    normalize.(a) == normalize.(b)
  end
end
