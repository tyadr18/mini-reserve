module ApplicationHelper
  # 「2026年12月1日（火） 12:00」の形で来店日時を表示する
  def format_reserved_at(reservation)
    "#{l(reservation.reserved_on, format: :long)} #{reservation.time_slot}"
  end
end
