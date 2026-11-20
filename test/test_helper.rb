ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # test/fixtures/*.yml をすべて読み込む。日付は実行日からの相対値なので、いつ実行しても未来の予約になる
    fixtures :all

    # 予約の属性をそろえて組み立てる。上書きしたい項目だけ渡す
    def build_reservation(**attributes)
      Reservation.new(
        customer_name: "テスト 太郎",
        contact: "090-0000-0000",
        reserved_on: Date.current + 30,
        time_slot: "18:00",
        party_size: 2,
        **attributes
      )
    end
  end
end
