class CreateChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :checks do |t|
      t.references :uptime_monitor, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.boolean :up, null: false
      t.integer :http_status
      t.integer :response_time_ms
      t.string :error
      t.datetime :checked_at, null: false
    end
    add_index :checks, [ :uptime_monitor_id, :checked_at ]
    add_index :checks, :checked_at
  end
end
