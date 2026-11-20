require_relative "boot"

require "rails"
# 使うフレームワークだけを読み込む（メール・ジョブ・ファイル添付・WebSocket は使わない）
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module MiniReserve
  class Application < Rails::Application
    config.load_defaults 8.1

    config.time_zone = ENV.fetch("APP_TIME_ZONE", "Tokyo")

    config.i18n.available_locales = %i[ja en]
    config.i18n.default_locale = :ja
    config.i18n.fallbacks = [:en]

    # 予約まわりの設定値。環境変数で上書きできる（.env.example を参照）
    config.x.reservation.slot_capacity = Integer(ENV.fetch("SLOT_CAPACITY", "10"))
    config.x.reservation.max_party_size = Integer(ENV.fetch("MAX_PARTY_SIZE", "8"))

    config.generators do |g|
      g.system_tests nil
      g.helper false
    end
  end
end
