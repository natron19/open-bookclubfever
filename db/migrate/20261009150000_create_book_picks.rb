class CreateBookPicks < ActiveRecord::Migration[8.1]
  def change
    create_table :book_picks, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string  :title,        null: false
      t.string  :author,       null: false
      t.string  :read_through, null: false
      t.integer :chapter
      t.string  :club_vibe,    null: false
      t.text    :reader_notes

      t.timestamps null: false
    end
  end
end
