require "rails_helper"

RSpec.describe "BookPicks", type: :request do
  let(:user)      { create(:user) }
  let(:other)     { create(:user) }
  let(:book_pick) { create(:book_pick, user: user) }

  let(:valid_params) do
    { book_pick: { title: "Jane Eyre", author: "Charlotte Brontë", read_through: "up_to_chapter", chapter: "11",
                   club_vibe: "casual", reader_notes: "" } }
  end

  context "when not signed in" do
    it "redirects every page to sign in" do
      get book_picks_path
      expect(response).to redirect_to(sign_in_path)
      get dashboard_path
      expect(response).to redirect_to(sign_in_path)
      post book_picks_path, params: valid_params
      expect(response).to redirect_to(sign_in_path)
    end
  end

  context "when signed in" do
    before { sign_in_as(user) }

    it "shows the dashboard as My book club picks with only the user's own books" do
      create(:book_pick, user: user, title: "Mine to host")
      create(:book_pick, user: other, title: "Someone else's book")
      get dashboard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("My book club picks", "Mine to host")
      expect(response.body).not_to include("Someone else&#39;s book")
    end

    it "shows the boundary and whether openers are ready on the dashboard" do
      create(:conversation_set, :completed, book_pick: book_pick)
      get book_picks_path
      expect(response.body).to include("Up to the end of chapter 10", "5 openers ready")
    end

    it "shows an empty state with no books" do
      get book_picks_path
      expect(response.body).to include("Add your first book")
    end

    it "renders the new form with the labels the UI journey fills" do
      get new_book_pick_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Book title", "Author", "How far the club has read", "Chapter", "Club vibe", "Reader notes")
    end

    it "creates a book and redirects to it" do
      expect { post book_picks_path, params: valid_params }.to change(user.book_picks, :count).by(1)
      expect(response).to redirect_to(book_pick_path(BookPick.last))
      expect(BookPick.last.chapter).to eq(11)
    end

    it "re-renders the form with 422 when a partway club has no chapter" do
      expect {
        post book_picks_path, params: { book_pick: valid_params[:book_pick].merge(chapter: "") }
      }.not_to change(BookPick, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Chapter can&#39;t be blank")
    end

    it "shows the book with the Get five openers button" do
      get book_pick_path(book_pick)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(book_pick.title, "Up to the end of chapter 10", "Get five openers")
    end

    it "updates a book" do
      patch book_pick_path(book_pick), params: { book_pick: { chapter: "14" } }
      expect(response).to redirect_to(book_pick_path(book_pick))
      expect(book_pick.reload.chapter).to eq(14)
    end

    it "rejects an invalid update with 422" do
      patch book_pick_path(book_pick), params: { book_pick: { club_vibe: "rowdy" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "deletes a book" do
      book_pick
      expect { delete book_pick_path(book_pick) }.to change(BookPick, :count).by(-1)
      expect(response).to redirect_to(book_picks_path)
    end
  end

  # open-base's ApplicationController answers RecordNotFound with a redirect to root and an alert.
  context "when signed in as a different user" do
    before { sign_in_as(other) }

    it "cannot see, edit, update, or delete the book" do
      get book_pick_path(book_pick)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("That record could not be found.")
      get edit_book_pick_path(book_pick)
      expect(response).to redirect_to(root_path)
      patch book_pick_path(book_pick), params: { book_pick: { title: "Hijacked" } }
      expect(response).to redirect_to(root_path)
      expect { delete book_pick_path(book_pick) }.not_to change(BookPick, :count)
      expect(response).to redirect_to(root_path)
      expect(book_pick.reload.title).not_to eq("Hijacked")
    end
  end
end
