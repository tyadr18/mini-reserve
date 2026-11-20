Rails.application.configure do
  config.enable_reloading = false

  # CI ではすべてのコードを読み込み、読み込みエラーを早めに見つける
  config.eager_load = ENV["CI"].present?

  config.consider_all_requests_local = true
  config.cache_store = :null_store

  # RecordNotFound などは本番と同じく 404 などのレスポンスとして返す
  config.action_dispatch.show_exceptions = :rescuable
  config.action_controller.allow_forgery_protection = false

  config.active_support.deprecation = :stderr
  config.action_controller.raise_on_missing_callback_actions = true

  # テストは環境変数に左右されないよう、設定値を固定する
  config.x.reservation.slot_capacity = 10
  config.x.reservation.max_party_size = 8
end
