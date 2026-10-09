require "rails_helper"

RSpec.describe ChapterBoundaryCheck do
  describe ".violations" do
    it "is empty for the whole book, whatever the text says" do
      expect(described_class.violations("The final chapter and chapter 40 are the best part.", nil)).to eq([])
    end

    it "allows chapters up to and including the club's chapter" do
      expect(described_class.violations("Chapter 10 ends on a glacier; chapters 1 to 10 are covered.", 10)).to eq([])
    end

    it "flags a chapter number past the club's chapter" do
      expect(described_class.violations("What happens in chapter 14 changes everything.", 10)).to eq([ "chapter 14" ])
    end

    it "flags ranges and lists that reach past it" do
      expect(described_class.violations("Chapters 9-12 move fast.", 10)).to eq([ "chapter 9-12" ])
      expect(described_class.violations("chapters 3, 7 and 11", 10)).to eq([ "chapter 3, 7 and 11" ])
      expect(described_class.violations("chapters 8 through 10", 10)).to eq([])
    end

    it "reads chapter numbers written as words" do
      expect(described_class.violations("Chapter Twelve is where it turns.", 10)).to eq([ "chapter Twelve" ])
      expect(described_class.violations("By chapter nine we know.", 10)).to eq([])
    end

    it "flags the final chapter and the epilogue for a club partway through" do
      expect(described_class.violations("Does the final chapter answer it?", 10)).to eq([ "the final chapter" ])
      expect(described_class.violations("The epilogue says otherwise.", 10)).to eq([ "epilogue" ])
    end

    it "does not read a word that only starts like a number" do
      expect(described_class.violations("The tension in chapter 4 builds.", 10)).to eq([])
    end
  end

  describe ".clean?" do
    it "is true for clean text and false otherwise" do
      expect(described_class.clean?("Chapter 3 has the storm.", 5)).to be(true)
      expect(described_class.clean?("Chapter 6 has the storm.", 5)).to be(false)
    end
  end
end
