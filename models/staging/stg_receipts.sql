-- Money columns cast to decimal, not double, so the sums stay exact.
with deduped as {{ dedupe_latest(source('remittances', 'receipts'), 'id', 'try_cast(created_at as timestamptz)') }}

select
    id as receipt_id,
    upper(destination_country_code) as destination_country_code,
    upper(destination_currency) as destination_currency,
    try_cast(amount_charged as decimal(18, 2)) as amount_charged,
    try_cast(fee as decimal(18, 2)) as fee,
    try_cast(exchange_rate as decimal(18, 6)) as exchange_rate,
    try_cast(promotion_amount as decimal(18, 2)) as promotion_amount,
    try_cast(destination_amount as decimal(18, 2)) as destination_amount,
    user_id as sender_user_id,
    payment_id,
    disbursement_id,
    beneficiary_id,
    try_cast(created_at as timestamptz) as created_at,
    _source_file,
    _loaded_at
from deduped
