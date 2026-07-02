class CreateWebhookLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :webhook_logs do |t|
      t.string :event_type
      t.text :payload

      t.timestamps
    end
  end
end
