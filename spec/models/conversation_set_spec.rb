require "rails_helper"

RSpec.describe ConversationSet, type: :model do
  describe "validations" do
    it "is valid with the factory attributes" do
      expect(build(:conversation_set)).to be_valid
      expect(build(:conversation_set, :completed)).to be_valid
    end

    it "requires a book pick" do
      expect(build(:conversation_set, book_pick: nil)).not_to be_valid
    end

    it "accepts every known status and rejects others" do
      ConversationSet::STATUSES.each { |s| expect(build(:conversation_set, status: s)).to be_valid }
      expect(build(:conversation_set, status: "unknown")).not_to be_valid
    end

    it "accepts known or unsure familiarity, or none before it completes" do
      ConversationSet::FAMILIARITIES.each { |f| expect(build(:conversation_set, book_familiarity: f)).to be_valid }
      expect(build(:conversation_set, book_familiarity: nil)).to be_valid
      expect(build(:conversation_set, book_familiarity: "expert")).not_to be_valid
    end

    it "lists the statuses, angles and familiarities" do
      expect(ConversationSet::STATUSES).to eq(%w[pending completed failed])
      expect(ConversationSet::ANGLES).to eq(%w[theme character craft personal disagreement])
      expect(ConversationSet::FAMILIARITIES).to eq(%w[known unsure])
    end
  end

  describe "associations" do
    it "has a user through its book pick" do
      set = create(:conversation_set)
      expect(set.user).to eq(set.book_pick.user)
    end
  end

  describe "defaults" do
    it "starts pending with empty lists" do
      set = ConversationSet.create!(book_pick: create(:book_pick))
      expect(set.status).to eq("pending")
      expect([ set.openers, set.next_reads ]).to all(eq([]))
    end
  end

  describe "#stale?" do
    it "is true when the book pick changed after the openers were written" do
      set = create(:conversation_set, :completed, generated_at: 1.hour.ago)
      set.book_pick.update!(chapter: 12)
      expect(set.stale?).to be(true)
    end

    it "is false when the openers are newer than the book pick" do
      set = create(:conversation_set, :completed, generated_at: 1.minute.from_now)
      expect(set.stale?).to be(false)
    end
  end

  describe "#to_markdown" do
    it "includes the boundary, the five openers with follow-ups, the spoiler-free line and the next reads" do
      set = create(:conversation_set, :completed)
      md = set.to_markdown
      expect(md).to include("# Conversation openers: Frankenstein")
      expect(md).to include("Frankenstein by Mary Shelley. Up to the end of chapter 10; mixed club.")
      expect(md).to include("AI-generated")
      expect(md).to include("**Spoiler boundary:** Stays within chapters 1 to 10.")
      expect(md).to include("1. **#{set.openers.first['question']}** _(character)_")
      expect(md).to include("   - Follow-up: #{set.openers.last['follow_up']}")
      expect(md).to include("> #{set.spoiler_free_line}")
      expect(md).to include("- **Dracula** by Bram Stoker: Also told in letters and journals.")
      expect(md).not_to include("did not know this book well")
    end

    it "flags uncertainty when the AI did not know the book" do
      expect(create(:conversation_set, :unsure).to_markdown).to include("The AI did not know this book well")
    end

    it "names the file after the book title" do
      expect(create(:conversation_set, :completed).markdown_filename).to eq("frankenstein-openers.md")
    end
  end
end
