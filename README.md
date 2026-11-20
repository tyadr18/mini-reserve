# mini-reserve

A small reservation manager for local shops, built with Ruby on Rails 8 and SQLite.
It prevents overbooking per time slot and is covered by Minitest model and request tests.

![test](https://github.com/tyadr18/mini-reserve/actions/workflows/test.yml/badge.svg)

> ポートフォリオ用の作例です。実在の店舗・クライアントの案件ではありません。データはすべて架空のものです。

## 概要

飲食店やサロンのような小さな店舗で、電話や来店で受けた予約を記録するための管理画面です。

- 予約の登録・一覧・詳細・編集・削除（お客様名／連絡先／予約日／時間枠／人数／備考）
- **予約枠の重複チェック**：同じ日付・同じ時間枠に入る人数の合計が定員を超える予約は登録できません
- **入力チェック**：必須項目、過去日時の禁止（当日の開始時刻を過ぎた枠も不可）、1件あたりの人数上限、連絡先の形式（電話番号かメールアドレス）、文字数の上限
- **日付での絞り込み**：日付を選ぶと、その日の予約と時間枠ごとの空き状況（予約人数／残り）を表示します。空いている枠からは日付と時間枠が入った状態で予約画面を開けます

指定がないときの一覧は「今日以降の予約」です。過去の予約も、日付を指定すれば確認できます。

## 使った技術

| 区分 | 内容 |
| --- | --- |
| 言語 | Ruby 3.4 |
| フレームワーク | Ruby on Rails 8.1 |
| データベース | SQLite |
| テスト | Minitest（モデルテスト・リクエストテスト） |
| CI | GitHub Actions（push と pull request でテストを自動実行） |

画面は Rails 標準の ERB ビューと素の CSS だけで作っており、JavaScript のビルドは使っていません。

## 動かし方

### 必要なもの

- Ruby 3.4 系（rbenv・mise などで用意してください）
- Bundler
- SQLite 3

### セットアップと起動

```bash
git clone https://github.com/tyadr18/mini-reserve.git
cd mini-reserve
bin/setup          # gem のインストールとデータベースの作成
bin/rails db:seed  # 架空のサンプル予約を入れる（任意）
bin/rails server
```

ブラウザで http://localhost:3000 を開くと予約一覧が表示されます。

### テスト

```bash
bin/rails db:test:prepare
bin/rails test
```

### 設定

設定値は環境変数で変えられます。一覧と既定値は [`.env.example`](.env.example) にまとめています。

| 環境変数 | 意味 | 既定値 |
| --- | --- | --- |
| `SLOT_CAPACITY` | 1つの時間枠の定員（人数の合計） | `10` |
| `MAX_PARTY_SIZE` | 1件の予約で受け付ける人数の上限 | `8` |
| `APP_TIME_ZONE` | 予約日時の判定に使うタイムゾーン | `Tokyo` |
| `SECRET_KEY_BASE` | 本番環境でのみ必要（`bin/rails secret` で生成） | なし |

```bash
SLOT_CAPACITY=20 MAX_PARTY_SIZE=10 bin/rails server
```

テストは環境変数の影響を受けないよう、`config/environments/test.rb` で定員10名・上限8名に固定しています。

時間枠は `app/models/reservation.rb` の `TIME_SLOTS`（11:00〜13:00、17:00〜20:00）で定義しています。

## 工夫点

**定員チェックを「数」ではなく「人数の合計」で行う**
同じ枠の予約件数ではなく人数を合計し、新しい予約の人数を足して定員を超えるかどうかで判定しています。エラーには「この時間枠の残りは3名です」のように残り人数を出すので、受付側はそのまま人数や枠の変更を提案できます。

**編集時に自分自身を二重に数えない**
既存の予約を編集するときは、その予約自身を集計から外して判定します（`booked_party_size(..., except_id: id)`）。4名の予約を5名に増やすとき、元の4名を「すでに埋まっている分」として数えてしまう不具合を防いでいます。

**同時に予約が入ったときの取りこぼし対策**
「空きを確認してから保存する」処理は、2件の予約がほぼ同時に来ると両方とも通ってしまうおそれがあります。`config/database.yml` で SQLite の `default_transaction_mode: immediate` を指定し、トランザクション開始の時点で書き込みロックを取るようにしました。Rails のバリデーションは保存と同じトランザクションの中で動くため、定員チェックから保存までの間に別の書き込みが割り込みません。

**チェックが必要なときだけ確認する**
過去日時のチェックは新規作成時と日時を変えたときだけ行います。来店済みの予約の備考を後から直す、といった操作が「過去日時です」で弾かれないようにするためです。定員チェックも、日時か人数が変わったときだけ行います。

**入力の表記ゆれを保存前にそろえる**
連絡先は全角数字やハイフンを半角に直し、お客様名は前後や連続する空白（全角スペースを含む）を整えてから保存します（Rails の `normalizes`）。電話番号は「0で始まり、ハイフンを除いて10〜11桁」で判定しています。

**個人情報をログに残さない**
お客様名・連絡先・備考はパラメータのログで `[FILTERED]` に置き換わるよう設定しています（`config/initializers/filter_parameter_logging.rb`）。

**テストが実行日に左右されない**
フィクスチャの予約日は「実行日の7日後」のように相対的に書いています。当日の時間枠の判定のように時刻が関わるテストは `travel_to` で日時を固定しています。

## ディレクトリ構成

主なファイルだけを載せています。

```
mini-reserve/
├── .github/workflows/test.yml       # GitHub Actions でテストを実行
├── app/
│   ├── controllers/
│   │   └── reservations_controller.rb   # 予約の CRUD と日付での絞り込み
│   ├── helpers/application_helper.rb    # 来店日時の表示
│   ├── models/
│   │   └── reservation.rb               # バリデーション・定員チェック・集計
│   └── views/
│       ├── layouts/application.html.erb
│       └── reservations/                # 一覧・詳細・新規・編集・フォーム
├── bin/                             # rails / rake / setup
├── config/
│   ├── application.rb               # タイムゾーン・言語・予約の設定値
│   ├── database.yml                 # SQLite（immediate トランザクション）
│   ├── environments/                # development / test / production
│   ├── initializers/filter_parameter_logging.rb
│   ├── locales/ja.yml               # 項目名とエラーメッセージ（日本語）
│   └── routes.rb
├── db/
│   ├── migrate/                     # reservations テーブルの作成
│   ├── schema.rb
│   └── seeds.rb                     # 架空のサンプルデータ
├── public/                          # styles.css とエラーページ
├── test/
│   ├── fixtures/reservations.yml
│   ├── models/reservation_test.rb               # バリデーション・定員チェック
│   ├── controllers/reservations_controller_test.rb  # 画面ごとのリクエストテスト
│   └── test_helper.rb
├── .env.example                     # 設定値のサンプル
├── Gemfile
└── Gemfile.lock
```

## 今後やりたいこと

- 店舗スタッフ向けのログイン
- 時間枠と定員を画面から設定できるようにする
- 予約確認メールの送信
