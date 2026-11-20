# お客様の個人情報をログに残さないよう、該当するパラメータを [FILTERED] に置き換える
Rails.application.config.filter_parameters += %i[
  customer_name contact note
  passw email secret token _key crypt salt certificate otp ssn cvv cvc
]
