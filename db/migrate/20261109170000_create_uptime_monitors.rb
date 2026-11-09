class CreateUptimeMonitors < ActiveRecord::Migration[8.1]
  def change
    create_table :uptime_monitors do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.integer :interval_seconds, null: false, default: 60
      t.integer :timeout_seconds, null: false, default: 10
      t.integer :expected_status_min, null: false, default: 200
      t.integer :expected_status_max, null: false, default: 399
      t.string :keyword
      t.integer :failure_threshold, null: false, default: 2
      t.boolean :active, null: false, default: true
      t.string :status, null: false, default: "pending"
      t.integer :consecutive_failures, null: false, default: 0
      t.datetime :last_checked_at
      t.datetime :next_check_at
      t.timestamps
    end
    add_index :uptime_monitors, [ :active, :next_check_at ]
  end
end
