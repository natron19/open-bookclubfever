require "rails_helper"

RSpec.describe BookPick, type: :model do
  describe "validations" do
    it "is valid with the factory attributes" do
      expect(build(:book_pick)).to be_valid
      expect(build(:book_pick, :whole_book)).to be_valid
    end

    it "requires a user" do
      expect(build(:book_pick, user: nil)).not_to be_valid
    end

    it "requires a title of at most 200 characters" do
      expect(build(:book_pick, title: "")).not_to be_valid
      expect(build(:book_pick, title: "x" * 201)).not_to be_valid
    end

    it "requires an author of at most 120 characters" do
      expect(build(:book_pick, author: "")).not_to be_valid
      expect(build(:book_pick, author: "x" * 121)).not_to be_valid
    end

    it "accepts every known read_through and club_vibe and rejects others" do
      BookPick::READ_THROUGHS.each { |r| expect(build(:book_pick, read_through: r)).to be_valid }
      BookPick::CLUB_VIBES.each { |v| expect(build(:book_pick, club_vibe: v)).to be_valid }
      expect(build(:book_pick, read_through: "half")).not_to be_valid
      expect(build(:book_pick, club_vibe: "rowdy")).not_to be_valid
      expect(build(:book_pick, club_vibe: nil)).not_to be_valid
    end

    it "requires a whole-number chapter from 1 to 500 when the club is partway through" do
      expect(build(:book_pick, chapter: nil)).not_to be_valid
      expect(build(:book_pick, chapter: 0)).not_to be_valid
      expect(build(:book_pick, chapter: 501)).not_to be_valid
      expect(build(:book_pick, chapter: 2.5)).not_to be_valid
      expect(build(:book_pick, chapter: 500)).to be_valid
    end

    it "clears the chapter when the club has read the whole book" do
      pick = create(:book_pick, read_through: "whole_book", chapter: 7)
      expect(pick.chapter).to be_nil
      expect(pick.last_chapter).to be_nil
    end

    it "allows blank reader notes but caps them at 1500 characters" do
      expect(build(:book_pick, reader_notes: nil)).to be_valid
      expect(build(:book_pick, reader_notes: "x" * 1501)).not_to be_valid
    end
  end

  describe "constants" do
    it "lists the read-throughs and vibes, each with a label (and a prompt phrase for vibes)" do
      expect(BookPick::READ_THROUGHS).to eq(%w[whole_book up_to_chapter])
      expect(BookPick::CLUB_VIBES).to eq(%w[casual deep_dive mixed])
      expect(BookPick::READ_THROUGH_LABELS.keys).to eq(BookPick::READ_THROUGHS)
      expect(BookPick::CLUB_VIBE_LABELS.keys).to eq(BookPick::CLUB_VIBES)
      expect(BookPick::CLUB_VIBE_PROMPTS.keys).to eq(BookPick::CLUB_VIBES)
    end
  end

  describe "associations" do
    it "destroys its conversation sets" do
      pick = create(:book_pick)
      create(:conversation_set, :completed, book_pick: pick)
      expect { pick.destroy }.to change(ConversationSet, :count).by(-1)
    end

    it "returns the newest set as latest_conversation_set" do
      pick = create(:book_pick)
      create(:conversation_set, :completed, book_pick: pick, generated_at: 2.days.ago)
      newest = create(:conversation_set, :completed, book_pick: pick, generated_at: 1.hour.ago)
      expect(pick.reload.latest_conversation_set).to eq(newest)
    end

    it "is destroyed with its user" do
      pick = create(:book_pick)
      expect { pick.user.destroy }.to change(BookPick, :count).by(-1)
    end
  end

  describe "#ai_variables" do
    it "sends the book, the chapter boundary, the vibe and the notes, and nothing about the member" do
      pick = build(:book_pick, chapter: 12, club_vibe: "deep_dive")
      vars = pick.ai_variables
      expect(vars.keys).to eq(%i[title author read_through club_vibe reader_notes])
      expect(vars[:read_through]).to start_with("up to the end of chapter 12.")
      expect(vars[:read_through]).to include("no chapter number above 12")
      expect(vars[:club_vibe]).to start_with("deep dive")
      expect(vars.values.join).not_to include(pick.user.name, pick.user.email)
    end

    it "says the ending is fair game for the whole book, and None for blank notes" do
      vars = build(:book_pick, :whole_book, reader_notes: "").ai_variables
      expect(vars[:read_through]).to start_with("the whole book.")
      expect(vars[:reader_notes]).to eq("None")
    end
  end

  describe "labels" do
    it "describes the boundary and the vibe" do
      expect(build(:book_pick, chapter: 4).read_through_label).to eq("Up to the end of chapter 4")
      expect(build(:book_pick, :whole_book).read_through_label).to eq("The whole book")
      expect(build(:book_pick, club_vibe: "deep_dive").club_vibe_label).to eq("Deep dive")
    end
  end
end
