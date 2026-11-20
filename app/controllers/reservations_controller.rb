class ReservationsController < ApplicationController
  PERMITTED_ATTRIBUTES = %i[customer_name contact reserved_on time_slot party_size note].freeze

  before_action :set_reservation, only: %i[show edit update destroy]

  # GET /reservations?date=2026-12-01
  # date を指定するとその日の予約だけ、指定しなければ今日以降の予約を表示する
  def index
    @date = parse_date(params[:date])
    @reservations = (@date ? Reservation.on_date(@date) : Reservation.upcoming).chronological.load
    @booked_party_sizes = Reservation.booked_party_sizes_on(@date) if @date
  end

  def show
  end

  # 一覧の空き状況から来たときは、日付と時間枠を入力済みにする
  def new
    @reservation = Reservation.new(party_size: 2, **prefill_params)
  end

  def edit
  end

  def create
    @reservation = Reservation.new(reservation_params)

    if @reservation.save
      redirect_to @reservation, notice: "予約を登録しました。"
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @reservation.update(reservation_params)
      redirect_to @reservation, notice: "予約を更新しました。"
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @reservation.destroy!
    redirect_to reservations_path(date: @reservation.reserved_on), notice: "予約を削除しました。", status: :see_other
  end

  private

  def set_reservation
    @reservation = Reservation.find(params[:id])
  end

  def reservation_params
    params.expect(reservation: PERMITTED_ATTRIBUTES)
  end

  # ?reservation=xxx のように形の違う値が来ても 500 にならないよう、permit してから取り出す
  def prefill_params
    prefill = params.permit(reservation: %i[reserved_on time_slot])[:reservation]
    prefill ? prefill.to_h.symbolize_keys : {}
  end

  # "2026-12-01" 形式の文字列を Date にする。空なら nil、不正な形式なら注意を出して nil
  def parse_date(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue Date::Error
    flash.now[:alert] = "日付の形式が正しくありません（例: 2026-12-01）。今日以降の予約を表示しています。"
    nil
  end
end
