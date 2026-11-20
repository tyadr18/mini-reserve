require "test_helper"

class ReservationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @lunch = reservations(:lunch_yamada)
    @dinner = reservations(:dinner_suzuki)
  end

  def valid_params(**overrides)
    {
      reservation: {
        customer_name: "新規 予約子",
        contact: "new@example.com",
        reserved_on: (Date.current + 10).iso8601,
        time_slot: "19:00",
        party_size: 2,
        note: "テスト"
      }.merge(overrides)
    }
  end

  # ---- 一覧・絞り込み ----

  test "トップページは予約一覧" do
    get root_url

    assert_response :success
    assert_select "h1", "予約一覧"
  end

  test "日付の指定がなければ今日以降の予約を表示する" do
    get reservations_url

    assert_response :success
    assert_select "##{dom_id(@lunch)}"
    assert_select "##{dom_id(@dinner)}"
    assert_select "##{dom_id(reservations(:past_tanaka))}", count: 0
  end

  test "日付で絞り込むとその日の予約と空き状況だけを表示する" do
    get reservations_url(date: @lunch.reserved_on.iso8601)

    assert_response :success
    assert_select "##{dom_id(@lunch)}"
    assert_select "##{dom_id(reservations(:lunch_sato))}"
    assert_select "##{dom_id(@dinner)}", count: 0
    assert_select "table.slots tbody tr", Reservation::TIME_SLOTS.size
    assert_select "table.slots", text: /3名/ # 12:00 枠の残り
  end

  test "過去の日付で絞り込めば過去の予約も確認できる" do
    past = reservations(:past_tanaka)
    get reservations_url(date: past.reserved_on.iso8601)

    assert_select "##{dom_id(past)}"
  end

  test "不正な日付を指定したら注意を出して今日以降の一覧を表示する" do
    get reservations_url(date: "2026-13-45")

    assert_response :success
    assert_select ".flash-alert", /日付の形式が正しくありません/
    assert_select "##{dom_id(@lunch)}"
  end

  # ---- 詳細・新規・編集画面 ----

  test "予約の詳細を表示できる" do
    get reservation_url(@lunch)

    assert_response :success
    assert_select "dd", @lunch.customer_name
  end

  test "存在しない予約は404" do
    get reservation_url(id: 0)

    assert_response :not_found
  end

  test "新規予約画面を表示できる" do
    get new_reservation_url

    assert_response :success
    assert_select "form.reservation-form"
  end

  test "空き状況のリンクから来たら日付と時間枠を入力済みにする" do
    date = (Date.current + 7).iso8601
    get new_reservation_url(reservation: { reserved_on: date, time_slot: "13:00" })

    assert_select "input[name='reservation[reserved_on]'][value='#{date}']"
    assert_select "select[name='reservation[time_slot]'] option[selected][value='13:00']"
  end

  test "入力済みにするパラメータの形が不正でも新規予約画面を表示できる" do
    get new_reservation_url, params: { reservation: "broken" }

    assert_response :success
  end

  test "編集画面を表示できる" do
    get edit_reservation_url(@lunch)

    assert_response :success
    assert_select "input[name='reservation[customer_name]'][value='#{@lunch.customer_name}']"
  end

  # ---- 登録 ----

  test "正しい内容なら予約を登録して詳細画面へ移動する" do
    assert_difference("Reservation.count", 1) do
      post reservations_url, params: valid_params
    end

    reservation = Reservation.order(:id).last
    assert_redirected_to reservation_url(reservation)
    assert_equal "新規 予約子", reservation.customer_name
    follow_redirect!
    assert_select ".flash", "予約を登録しました。"
  end

  test "必須項目が空なら登録せずにエラーを表示する" do
    assert_no_difference("Reservation.count") do
      post reservations_url, params: valid_params(customer_name: "")
    end

    assert_response :unprocessable_content
    assert_select ".errors li", "お客様名を入力してください"
  end

  test "過去の日時では登録できない" do
    assert_no_difference("Reservation.count") do
      post reservations_url, params: valid_params(reserved_on: (Date.current - 1).iso8601)
    end

    assert_response :unprocessable_content
    assert_select ".errors li", /現在より後の日時/
  end

  test "定員を超える予約は登録できない" do
    params = valid_params(reserved_on: @lunch.reserved_on.iso8601, time_slot: @lunch.time_slot, party_size: 4)

    assert_no_difference("Reservation.count") do
      post reservations_url, params: params
    end

    assert_response :unprocessable_content
    assert_select ".errors li", /定員を超えています/
  end

  test "reservation パラメータがなければ400" do
    post reservations_url, params: { foo: "bar" }

    assert_response :bad_request
  end

  # ---- 更新 ----

  test "予約を更新できる" do
    patch reservation_url(@lunch), params: { reservation: { party_size: 5, note: "1名追加" } }

    assert_redirected_to reservation_url(@lunch)
    @lunch.reload
    assert_equal 5, @lunch.party_size
    assert_equal "1名追加", @lunch.note
  end

  test "不正な内容では更新せずに編集画面を再表示する" do
    patch reservation_url(@lunch), params: { reservation: { party_size: 0 } }

    assert_response :unprocessable_content
    assert_equal 4, @lunch.reload.party_size
  end

  # ---- 削除 ----

  test "予約を削除するとその日の一覧へ戻る" do
    assert_difference("Reservation.count", -1) do
      delete reservation_url(@lunch)
    end

    assert_redirected_to reservations_url(date: @lunch.reserved_on)
    assert_response :see_other
  end

  private

  def dom_id(record)
    ActionView::RecordIdentifier.dom_id(record)
  end
end
