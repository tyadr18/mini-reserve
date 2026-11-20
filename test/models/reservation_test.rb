require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  test "必要な項目がそろっていれば有効" do
    assert build_reservation.valid?
  end

  # ---- 必須項目 ----

  test "お客様名・連絡先・予約日・時間枠・人数は必須" do
    reservation = Reservation.new

    assert_not reservation.valid?
    %i[customer_name contact reserved_on time_slot party_size].each do |attribute|
      assert reservation.errors.of_kind?(attribute, :blank), "#{attribute} の必須チェックがない"
    end
  end

  test "備考は空でもよい" do
    assert build_reservation(note: "").valid?
  end

  test "空白だけのお客様名は未入力として扱う" do
    reservation = build_reservation(customer_name: "　  ")

    assert_not reservation.valid?
    assert reservation.errors.of_kind?(:customer_name, :blank)
  end

  # ---- 文字数・形式 ----

  test "お客様名は50文字まで" do
    assert build_reservation(customer_name: "あ" * 50).valid?
    assert_not build_reservation(customer_name: "あ" * 51).valid?
  end

  test "備考は500文字まで" do
    assert build_reservation(note: "あ" * 500).valid?
    assert_not build_reservation(note: "あ" * 501).valid?
  end

  test "連絡先は電話番号かメールアドレスなら有効" do
    %w[090-1234-5678 09012345678 03-1234-5678 shop@example.com].each do |contact|
      assert build_reservation(contact: contact).valid?, "#{contact} が無効と判定された"
    end
  end

  test "連絡先が電話番号にもメールアドレスにも見えなければ無効" do
    %w[abc 090-1234 1234567890 090-1234-56789 name@].each do |contact|
      reservation = build_reservation(contact: contact)

      assert_not reservation.valid?, "#{contact} が有効と判定された"
      assert reservation.errors.of_kind?(:contact, :invalid)
    end
  end

  test "全角で入力した電話番号は半角にそろえて保存する" do
    reservation = build_reservation(contact: " ０９０－１２３４－５６７８ ")

    assert_equal "090-1234-5678", reservation.contact
    assert reservation.valid?
  end

  test "一覧にない時間枠は選べない" do
    reservation = build_reservation(time_slot: "15:00")

    assert_not reservation.valid?
    assert reservation.errors.of_kind?(:time_slot, :inclusion)
  end

  # ---- 人数 ----

  test "人数は1名から上限まで" do
    max = Reservation.max_party_size

    assert build_reservation(party_size: 1).valid?
    assert build_reservation(party_size: max).valid?
    assert_not build_reservation(party_size: 0).valid?
    assert_not build_reservation(party_size: max + 1).valid?
  end

  test "人数は整数のみ" do
    reservation = build_reservation(party_size: "2.5")

    assert_not reservation.valid?
    assert reservation.errors.of_kind?(:party_size, :not_an_integer)
  end

  # ---- 過去日時 ----

  test "過去の日付では予約できない" do
    reservation = build_reservation(reserved_on: Date.current - 1)

    assert_not reservation.valid?
    assert reservation.errors.of_kind?(:reserved_on, :in_the_past)
  end

  test "当日でも開始時刻を過ぎた時間枠は予約できない" do
    travel_to Time.zone.local(2030, 1, 10, 15, 0) do
      assert_not build_reservation(reserved_on: Date.new(2030, 1, 10), time_slot: "12:00").valid?
      assert build_reservation(reserved_on: Date.new(2030, 1, 10), time_slot: "17:00").valid?
    end
  end

  test "過去の予約でも、日時を変えなければ備考を修正できる" do
    reservation = reservations(:past_tanaka)

    assert reservation.update(note: "来店済み")
  end

  test "過去の予約の日時を別の過去日時に変えることはできない" do
    reservation = reservations(:past_tanaka)

    assert_not reservation.update(reserved_on: Date.current - 2)
    assert reservation.errors.of_kind?(:reserved_on, :in_the_past)
  end

  # ---- 予約枠の重複（定員）チェック ----

  test "同じ枠の合計人数が定員ちょうどまでなら予約できる" do
    lunch = reservations(:lunch_yamada)

    # 既存 7名 + 3名 = 10名（定員）
    assert build_reservation(reserved_on: lunch.reserved_on, time_slot: lunch.time_slot, party_size: 3).valid?
  end

  test "同じ枠の合計人数が定員を超える予約はできない" do
    lunch = reservations(:lunch_yamada)
    reservation = build_reservation(reserved_on: lunch.reserved_on, time_slot: lunch.time_slot, party_size: 4)

    assert_not reservation.valid?
    assert reservation.errors.added?(:party_size, :over_capacity, remaining: 3)
    assert_includes reservation.errors.full_messages.join, "残りは3名"
  end

  test "日付か時間枠が違えば定員のカウントに含めない" do
    lunch = reservations(:lunch_yamada)

    assert build_reservation(reserved_on: lunch.reserved_on, time_slot: "13:00", party_size: 8).valid?
    assert build_reservation(reserved_on: lunch.reserved_on + 1, time_slot: lunch.time_slot, party_size: 8).valid?
  end

  test "編集するときは自分自身の人数を二重に数えない" do
    lunch = reservations(:lunch_yamada)

    # 自分(4名)を除くと 3名なので、7名まで増やせる
    assert lunch.update(party_size: 7)
    assert_not lunch.update(party_size: 8)
    assert lunch.errors.of_kind?(:party_size, :over_capacity)
  end

  test "満席の枠へ日時を変更することはできない" do
    lunch = reservations(:lunch_yamada)
    dinner = reservations(:dinner_suzuki)
    lunch.update!(party_size: 7) # 12:00 の枠を 10名（満席）にする

    assert_not dinner.update(reserved_on: lunch.reserved_on, time_slot: lunch.time_slot)
    assert dinner.errors.added?(:party_size, :over_capacity, remaining: 0)
  end

  # ---- クラスメソッド・スコープ ----

  test "枠ごとの予約人数を集計できる" do
    date = reservations(:lunch_yamada).reserved_on

    assert_equal 7, Reservation.booked_party_size(date, "12:00")
    assert_equal({ "12:00" => 7 }, Reservation.booked_party_sizes_on(date))
  end

  test "upcoming は今日以降の予約だけを返す" do
    assert_includes Reservation.upcoming, reservations(:lunch_yamada)
    assert_not_includes Reservation.upcoming, reservations(:past_tanaka)
  end

  test "reserved_at は予約日と時間枠を合わせた日時を返す" do
    reservation = build_reservation(reserved_on: Date.new(2030, 1, 10), time_slot: "18:00")

    assert_equal Time.zone.local(2030, 1, 10, 18, 0), reservation.reserved_at
    assert_nil build_reservation(time_slot: "99:99").reserved_at
  end
end
