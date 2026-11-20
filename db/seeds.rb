# 動作確認用のサンプルデータです。名前・連絡先はすべて架空のものです。
# `bin/rails db:seed` で投入できます（何度実行しても重複しません）。
samples = [
  { customer_name: "予約 太郎", contact: "090-0000-0001", days_later: 1, time_slot: "12:00", party_size: 2, note: "窓際の席を希望" },
  { customer_name: "見本 花子", contact: "hanako@example.com", days_later: 1, time_slot: "12:00", party_size: 4 },
  { customer_name: "試験 一郎", contact: "03-0000-0000", days_later: 2, time_slot: "18:00", party_size: 6, note: "誕生日のお祝い" },
  { customer_name: "架空 次郎", contact: "jiro@example.com", days_later: 3, time_slot: "19:00", party_size: 3 }
]

samples.each do |sample|
  reserved_on = Date.current + sample.delete(:days_later)
  Reservation.find_or_create_by!(customer_name: sample[:customer_name], reserved_on: reserved_on) do |reservation|
    reservation.assign_attributes(sample)
  end
end

puts "サンプル予約: #{Reservation.count}件"
