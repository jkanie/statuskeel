class CreateSubscribers < ActiveRecord::Migration[8.1]
  def change
    create_table :subscribers do |t|
      t.string :email_address, null: false
      t.datetime :confirmed_at
      t.timestamps
    end
    add_index :subscribers, :email_address, unique: true
    add_index :subscribers, :confirmed_at
  end
end
