require "rails_helper"

RSpec.describe ProgressShameCheck do
  describe ".found_in" do
    {
      "If you've fallen behind, no worries."               => "fallen behind",
      "Some people are behind on the reading."             => "behind on the reading",
      "For anyone who hasn't finished yet, skip this one." => "anyone who hasn't finished",
      "Who has finished the book?"                         => "Who has finished",
      "Did everyone finish?"                               => "Did everyone finish",
      "Plenty of time to catch up on the chapters."        => "catch up on the chapters",
      "Slow readers welcome!"                              => "Slow readers",
      "How far along is everyone?"                         => "How far along",
      "Hard to keep up with the club this month."          => "keep up with the club",
      "If you're behind, start with question two."         => "'re behind",
      "Not done with the book? Fine."                      => "Not done with the book"
    }.each do |text, phrase|
      it "flags #{phrase.inspect}" do
        expect(described_class.found_in(text)).to include(phrase)
      end
    end

    [
      "Who is behind the letters Walton writes?",
      "Newland is caught up in what everyone will say.",
      "Does Victor ever catch up with the creature?",
      "How far would you go to keep a promise?",
      "Have you read anything else by Edith Wharton?",
      "What did the people left behind in Geneva think?",
      "The man behind the curtain finally speaks."
    ].each do |text|
      it "leaves plot language alone: #{text.inspect}" do
        expect(described_class.found_in(text)).to eq([])
      end
    end
  end

  describe ".clean?" do
    it "is true for clean text and false otherwise" do
      expect(described_class.clean?("What would you have done in Victor's place?")).to be(true)
      expect(described_class.clean?("Who has finished?")).to be(false)
    end
  end
end
