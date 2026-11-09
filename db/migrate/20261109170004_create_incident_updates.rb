class CreateIncidentUpdates < ActiveRecord::Migration[8.1]
  def change
    create_table :incident_updates do |t|
      t.references :incident, null: false, foreign_key: { on_delete: :cascade }
      t.string :status, null: false
      t.timestamps
    end
  end
end
