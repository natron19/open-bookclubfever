require "rails_helper"

RSpec.describe "ConversationSets", type: :request do
  let(:user)      { create(:user) }
  let(:other)     { create(:user) }
  let(:book_pick) { create(:book_pick, user: user) }

  let(:valid_result) do
    {
      "book_familiarity"  => "known",
      "spoiler_boundary"  => "Stays within chapters 1 to 10.",
      "openers"           => [
        { "question" => "Victor runs from the creature the night he makes it; what would you have done?", "angle" => "character",
          "why_it_works" => "Everyone remembers the scene.", "follow_up" => "Is running away human?" },
        { "question" => "Is Victor hard to like on purpose?", "angle" => "disagreement",
          "why_it_works" => "The room will split.", "follow_up" => "Do we need someone to root for?" },
        { "question" => "Why tell it through Walton's letters?", "angle" => "craft",
          "why_it_works" => "It gets people looking at how the book is built.", "follow_up" => "Did you trust Victor more?" },
        { "question" => "Is Victor's silence at the trial the scariest thing in chapter 8?", "angle" => "theme",
          "why_it_works" => "Moves the talk to responsibility.", "follow_up" => "What would speaking have cost him?" },
        { "question" => "Have you ever kept a project to yourself until it felt too big to share?", "angle" => "personal",
          "why_it_works" => "Anyone can answer it.", "follow_up" => "What made you tell someone?" }
      ],
      "spoiler_free_line" => "Chapter 10 ends on a glacier with a conversation you will want to talk about.",
      "next_reads"        => [
        { "title" => "Strange Case of Dr Jekyll and Mr Hyde", "author" => "Robert Louis Stevenson", "tie_in" => "Another maker who cannot face what he made." },
        { "title" => "The Island of Doctor Moreau", "author" => "H. G. Wells", "tie_in" => "What does a maker owe his creatures?" },
        { "title" => "Dracula", "author" => "Bram Stoker", "tie_in" => "Also told in letters and journals." }
      ]
    }
  end

  def with_opener(index, changes)
    valid_result.merge("openers" => valid_result["openers"].each_with_index.map { |o, i| i == index ? o.merge(changes) : o })
  end

  def run_openers
    post book_pick_conversation_sets_path(book_pick)
  end

  describe "POST /books/:book_pick_id/openers" do
    context "when not signed in" do
      it "redirects to sign in" do
        run_openers
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in as the owner with a valid response" do
      before do
        sign_in_as(user)
        gemini_returns(valid_result.to_json)
      end

      it "calls GeminiService with the template and the book's variables" do
        expect(GeminiService).to receive(:generate).with(
          template:  "bookclubfever_openers_v1",
          variables: book_pick.ai_variables
        ).and_return(valid_result.to_json)
        run_openers
      end

      it "creates a completed set with the parsed fields and the raw response" do
        expect { run_openers }.to change(ConversationSet, :count).by(1)
        set = ConversationSet.last
        expect(set.status).to eq("completed")
        expect(set.gemini_raw).to eq(valid_result.to_json)
        expect(set.book_familiarity).to eq("known")
        expect(set.openers.size).to eq(5)
        expect(set.openers.first.keys).to match_array(%w[question angle why_it_works follow_up])
        expect(set.next_reads.map { |r| r["author"] }).to include("Bram Stoker")
        expect(set.generated_at).to be_present
      end

      it "redirects to the result page" do
        run_openers
        expect(response).to redirect_to(book_pick_conversation_set_path(book_pick, ConversationSet.last))
      end

      it "accepts a response wrapped in a ```json fence" do
        gemini_returns("```json\n#{valid_result.to_json}\n```")
        run_openers
        expect(ConversationSet.last.status).to eq("completed")
      end

      it "accepts capitalized angles and familiarity and stores them lowercase" do
        gemini_returns(with_opener(0, "angle" => "Character").merge("book_familiarity" => "Unsure").to_json)
        run_openers
        set = ConversationSet.last
        expect(set.status).to eq("completed")
        expect(set.openers.first["angle"]).to eq("character")
        expect(set.book_familiarity).to eq("unsure")
      end

      it "allows the ending and late chapters when the club has read the whole book" do
        book_pick.update!(read_through: "whole_book")
        gemini_returns(with_opener(0, "question" => "Does the final chapter in chapter 24 earn its ending?").to_json)
        run_openers
        expect(ConversationSet.last.status).to eq("completed")
      end
    end

    context "when the response cannot be used" do
      before { sign_in_as(user) }

      {
        "is not JSON"                          => ->(r) { "this is not json at all" },
        "is a JSON array"                      => ->(r) { "[1, 2]" },
        "has an unknown familiarity"           => ->(r) { r.merge("book_familiarity" => "expert").to_json },
        "has no spoiler boundary"              => ->(r) { r.merge("spoiler_boundary" => " ").to_json },
        "has no spoiler-free line"             => ->(r) { r.except("spoiler_free_line").to_json },
        "has four openers"                     => ->(r) { r.merge("openers" => r["openers"].first(4)).to_json },
        "has an opener without a follow-up"    => ->(r) { r.merge("openers" => r["openers"].each_with_index.map { |o, i| i.zero? ? o.except("follow_up") : o }).to_json },
        "has an unknown angle"                 => ->(r) { r.merge("openers" => r["openers"].each_with_index.map { |o, i| i.zero? ? o.merge("angle" => "plot") : o }).to_json },
        "uses only two angles"                 => ->(r) { r.merge("openers" => r["openers"].each_with_index.map { |o, i| o.merge("angle" => i.even? ? "theme" : "craft") }).to_json },
        "has an opener over 160 characters"    => ->(r) { r.merge("openers" => r["openers"].each_with_index.map { |o, i| i.zero? ? o.merge("question" => "Why? " * 40) : o }).to_json },
        "has two next reads"                   => ->(r) { r.merge("next_reads" => r["next_reads"].first(2)).to_json },
        "suggests the same book as a next read" => ->(r) { r.merge("next_reads" => r["next_reads"].first(2) + [ { "title" => "Frankenstein; or, The Modern Prometheus", "author" => "Mary Shelley", "tie_in" => "Read it again." } ]).to_json },
        "contains a link"                      => ->(r) { r.merge("next_reads" => r["next_reads"].first(2) + [ { "title" => "Dracula", "author" => "Bram Stoker", "tie_in" => "Free at https://example.org/dracula." } ]).to_json }
      }.each do |description, build|
        it "marks the set failed and keeps the raw text when the response #{description}" do
          text = build.call(valid_result)
          gemini_returns(text)

          expect { run_openers }.to change(ConversationSet, :count).by(1)
          set = ConversationSet.last
          expect(set.status).to eq("failed")
          expect(set.gemini_raw).to eq(text)
          expect(set.failure_reason).to be_present
          expect(response).to redirect_to(book_pick_conversation_set_path(book_pick, set))
        end
      end

      it "fails a response that reaches past the club's chapter (ChapterBoundaryCheck)" do
        gemini_returns(with_opener(3, "question" => "What do you make of the cottage family in chapter 12?").to_json)

        run_openers
        set = ConversationSet.last
        expect(set.status).to eq("failed")
        expect(set.failure_reason).to include("chapter 12", "past the club's chapter 10")

        follow_redirect!
        expect(response.body).to include("could not be used", "past the club&#39;s chapter 10", "Retry", "the cottage family in chapter 12")
        expect(response.body).not_to include("Download .md")
      end

      it "fails a response that hints someone is behind (ProgressShameCheck)" do
        gemini_returns(valid_result.merge("spoiler_free_line" => "Plenty of time to catch up on the reading before Thursday!").to_json)

        run_openers
        set = ConversationSet.last
        expect(set.status).to eq("failed")
        expect(set.failure_reason).to include("hinted that someone is behind", "catch up on the reading")

        follow_redirect!
        expect(response.body).to include("hinted that someone is behind", "Retry")
        expect(response.body).not_to include("Download .md")
      end
    end

    context "when GeminiService raises" do
      before { sign_in_as(user) }

      {
        GeminiService::BudgetExceededError => "daily AI request limit",
        GeminiService::GatekeeperError     => "couldn't be processed",
        GeminiService::OutputGuardError    => "didn't pass our safety checks",
        GeminiService::TimeoutError        => "took too long",
        GeminiService::GeminiError         => "An unexpected error occurred"
      }.each do |error_class, message|
        it "renders the #{error_class.name.demodulize} message with 422 and creates no set" do
          gemini_raises(error_class)
          expect { run_openers }.not_to change(ConversationSet, :count)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include(message, "Try again")
        end
      end
    end

    # open-base's ApplicationController answers RecordNotFound with a redirect to root and an alert.
    context "when signed in as a different user" do
      it "does not find the book, calls no AI, and creates no set" do
        sign_in_as(other)
        expect(GeminiService).not_to receive(:generate)
        expect { run_openers }.not_to change(ConversationSet, :count)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("That record could not be found.")
      end
    end

    context "rate limit" do
      it "refuses the 11th request within a minute" do
        sign_in_as(user)
        gemini_returns(valid_result.to_json)
        10.times { run_openers }
        expect(response).to have_http_status(:redirect)
        run_openers
        expect(response).to have_http_status(:too_many_requests)
        expect(ConversationSet.count).to eq(10)
      end
    end
  end

  describe "GET /books/:book_pick_id/openers (the error page's Try again)" do
    it "redirects to the book" do
      sign_in_as(user)
      get book_pick_conversation_sets_path(book_pick)
      expect(response).to redirect_to(book_pick_path(book_pick))
    end
  end

  describe "GET /books/:book_pick_id/openers/:id" do
    context "for a completed set" do
      let(:set) { create(:conversation_set, :completed, book_pick: book_pick, generated_at: 1.minute.from_now) }

      it "shows the boundary, openers, follow-ups, spoiler-free line, next reads, actions and disclaimer" do
        sign_in_as(user)
        get book_pick_conversation_set_path(book_pick, set)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(
          "Spoiler boundary:", set.spoiler_boundary, "Five openers", "Is Victor hard to like on purpose?", "disagreement",
          "Why it works:", "Follow-up:", set.openers.last["follow_up"], "A spoiler-free line for the group chat",
          "If the club liked this, read next", "The Island of Doctor Moreau", "H. G. Wells",
          "Download .md", "Show raw response", "AI-generated."
        )
        expect(response.body).not_to include("didn&rsquo;t know this book well", "have changed since")
      end
    end

    it "flags uncertainty when the AI did not know the book" do
      set = create(:conversation_set, :unsure, book_pick: book_pick)
      sign_in_as(user)
      get book_pick_conversation_set_path(book_pick, set)
      expect(response.body).to include("didn&rsquo;t know this book well")
    end

    context "for a failed set" do
      it "shows the reason, Retry, and the raw response, with no download" do
        set = create(:conversation_set, :failed, book_pick: book_pick)
        sign_in_as(user)
        get book_pick_conversation_set_path(book_pick, set)
        expect(response.body).to include("could not be used", set.failure_reason, "Retry", "malformed response")
        expect(response.body).not_to include("Download .md")
      end
    end

    it "warns when the book changed after the openers were written" do
      set = create(:conversation_set, :completed, book_pick: book_pick, generated_at: 1.hour.ago)
      book_pick.update!(chapter: 14)
      sign_in_as(user)
      get book_pick_conversation_set_path(book_pick, set)
      expect(response.body).to include("have changed since these openers were written")
    end

    it "does not show another user's set" do
      set = create(:conversation_set, :completed, book_pick: book_pick)
      sign_in_as(other)
      get book_pick_conversation_set_path(book_pick, set)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("That record could not be found.")
    end

    it "does not show a set under a different book of the same user" do
      set = create(:conversation_set, :completed, book_pick: book_pick)
      sign_in_as(user)
      get book_pick_conversation_set_path(create(:book_pick, user: user), set)
      expect(response).to redirect_to(root_path)
    end
  end
end
