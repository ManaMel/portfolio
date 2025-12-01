class CreateProfiles < ActiveRecord::Migration[7.2]
  def change
    create_table :profiles, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.text :musical_carrer

      t.timestamps
    end
  end
end
