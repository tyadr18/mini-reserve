class CreateReservations < ActiveRecord::Migration[8.1]
  def change
    create_table :reservations do |t|
      t.string :customer_name, null: false
      t.string :contact, null: false
      t.date :reserved_on, null: false
      t.string :time_slot, null: false
      t.integer :party_size, null: false
      t.text :note

      t.timestamps
    end

    # 定員チェックは「日付＋時間枠」で絞り込むため、その組み合わせに索引を張る
    add_index :reservations, %i[reserved_on time_slot]
    add_check_constraint :reservations, "party_size > 0", name: "party_size_positive"
  end
end
