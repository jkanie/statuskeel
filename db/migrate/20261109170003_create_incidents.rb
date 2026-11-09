class CreateIncidents < ActiveRecord::Migration[8.1]
  def change
    create_table :incidents do |t|
      t.string :title, null: false
      t.string :status, null: false, default: "investigating"
      t.string :impact, null: false, default: "minor"
      t.references :uptime_monitor, foreign_key: { on_delete: :nullify }
      t.boolean :automatic, null: false, default: false
      t.datetime :started_at, null: false
      t.datetime :resolved_at
      t.timestamps
    end
    add_index :incidents, :status
    add_index :incidents, :resolved_at
  end
end
