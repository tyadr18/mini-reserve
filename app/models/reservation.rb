# 店舗の予約1件を表すモデル。
#
# 予約日（reserved_on）と時間枠（time_slot）の組み合わせを「枠」と呼び、
# 1つの枠に入る人数の合計が定員（slot_capacity）を超えないようにする。
class Reservation < ApplicationRecord
  # 受け付ける時間枠（開始時刻）。"HH:MM" のゼロ埋めなので文字列のまま並べ替えられる
  TIME_SLOTS = %w[11:00 12:00 13:00 17:00 18:00 19:00 20:00].freeze

  CUSTOMER_NAME_MAX_LENGTH = 50
  CONTACT_MAX_LENGTH = 100
  NOTE_MAX_LENGTH = 500

  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP
  # 0 で始まる数字をハイフンで区切ったもの（ハイフンなしも可）
  PHONE_FORMAT = /\A0\d+(?:-\d+){0,2}\z/
  PHONE_DIGITS = (10..11)

  # 全角の数字やハイフン・前後の空白を揃えてから保存する
  normalizes :customer_name, with: ->(value) { value.squish }
  normalizes :contact, with: ->(value) { value.unicode_normalize(:nfkc).gsub(/[‐－−ー]/, "-").strip }
  normalizes :note, with: ->(value) { value.strip.presence }

  scope :on_date, ->(date) { where(reserved_on: date) }
  scope :upcoming, -> { where(reserved_on: Date.current..) }
  scope :chronological, -> { order(:reserved_on, :time_slot, :id) }

  validates :customer_name, presence: true, length: { maximum: CUSTOMER_NAME_MAX_LENGTH }
  validates :contact, presence: true, length: { maximum: CONTACT_MAX_LENGTH }
  validates :reserved_on, presence: true
  validates :time_slot, presence: true, inclusion: { in: TIME_SLOTS, allow_blank: true }
  validates :party_size,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: ->(_reservation) { max_party_size },
              allow_nil: true
            }
  validates :note, length: { maximum: NOTE_MAX_LENGTH }

  validate :contact_must_be_email_or_phone
  validate :reserved_at_must_be_in_future, if: :schedule_changing?
  validate :slot_must_have_room, if: :capacity_check_needed?

  class << self
    def slot_capacity
      Rails.configuration.x.reservation.slot_capacity
    end

    def max_party_size
      Rails.configuration.x.reservation.max_party_size
    end

    # 指定した枠に入っている人数の合計。編集中の予約自身は except_id で除外する
    def booked_party_size(date, time_slot, except_id: nil)
      scope = where(reserved_on: date, time_slot: time_slot)
      scope = scope.where.not(id: except_id) if except_id
      scope.sum(:party_size)
    end

    # 指定日の枠ごとの予約人数 { "12:00" => 7, ... }。一覧画面の空き状況表示用
    def booked_party_sizes_on(date)
      on_date(date).group(:time_slot).sum(:party_size)
    end
  end

  # 予約日と時間枠を合わせた来店日時（アプリのタイムゾーン）。どちらかが不正なら nil
  def reserved_at
    return if reserved_on.blank? || !TIME_SLOTS.include?(time_slot)

    hour, minute = time_slot.split(":").map(&:to_i)
    Time.zone.local(reserved_on.year, reserved_on.month, reserved_on.day, hour, minute)
  end

  private

  def schedule_changing?
    new_record? || will_save_change_to_reserved_on? || will_save_change_to_time_slot?
  end

  def capacity_check_needed?
    schedule_changing? || will_save_change_to_party_size?
  end

  def contact_must_be_email_or_phone
    return if contact.blank?
    return if contact.match?(EMAIL_FORMAT)
    return if contact.match?(PHONE_FORMAT) && PHONE_DIGITS.cover?(contact.delete("-").length)

    errors.add(:contact, :invalid)
  end

  # 新規作成時と日時を変えたときだけ確認する。過去の予約の備考だけを直す、といった編集は通す
  def reserved_at_must_be_in_future
    return if reserved_at.nil?

    errors.add(:reserved_on, :in_the_past) if reserved_at <= Time.current
  end

  def slot_must_have_room
    return if reserved_at.nil? || party_size.nil? || errors.include?(:party_size)

    remaining = self.class.slot_capacity -
                self.class.booked_party_size(reserved_on, time_slot, except_id: id)
    return if party_size <= remaining

    errors.add(:party_size, :over_capacity, remaining: remaining.clamp(0..))
  end
end
