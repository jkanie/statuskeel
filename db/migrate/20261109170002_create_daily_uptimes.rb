class CreateDailyUptimes < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_uptimes do |t|
      t.references :uptime_monitor, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.date :date, null: false
      t.integer :checks_count, null: false, default: 0
      t.integer :up_count, null: false, default: 0
    end
    add_index :daily_uptimes, [ :uptime_monitor_id, :date ], unique: true
    add_index :daily_uptimes, :date
  end
end
