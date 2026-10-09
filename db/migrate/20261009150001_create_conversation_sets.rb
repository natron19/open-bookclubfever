class CreateConversationSets < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_sets, id: :uuid do |t|
      t.references :book_pick, type: :uuid, null: false, foreign_key: true
      t.string   :status, null: false, default: "pending"
      t.text     :gemini_raw
      t.string   :failure_reason
      t.datetime :generated_at

      t.string :book_familiarity
      t.text   :spoiler_boundary
      t.jsonb  :openers,    null: false, default: []
      t.text   :spoiler_free_line
      t.jsonb  :next_reads, null: false, default: []

      t.timestamps null: false
    end
    add_index :conversation_sets, :status
  end
end
