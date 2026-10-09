class BookPicksController < ApplicationController
  before_action :set_book_pick, only: %i[show edit update destroy]

  def index
    @book_picks = current_user.book_picks.includes(:latest_conversation_set).order(created_at: :desc)
  end

  def show
    @conversation_sets = @book_pick.conversation_sets.order(created_at: :desc)
  end

  def new
    @book_pick = current_user.book_picks.build(read_through: "whole_book", club_vibe: "mixed")
  end

  def create
    @book_pick = current_user.book_picks.build(book_pick_params)
    if @book_pick.save
      redirect_to @book_pick
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @book_pick.update(book_pick_params)
      redirect_to @book_pick
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @book_pick.destroy
    redirect_to book_picks_path
  end

  private

  def set_book_pick
    @book_pick = current_user.book_picks.find(params[:id])
  end

  def book_pick_params
    params.require(:book_pick).permit(:title, :author, :read_through, :chapter, :club_vibe, :reader_notes)
  end
end
