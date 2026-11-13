-- amount keeps 4 decimals. Some rows came through a float32 field upstream
-- (122.989997864 is 122.99) and others carry real half-cent values.
with deduped as {{ dedupe_latest(source('remittances', 'payments'), 'id', 'try_cast(updated_at as timestamptz)') }}

select
    id as payment_id,
    try_cast(amount as decimal(18, 4)) as amount,
    upper(currency) as currency,
    user_id as sender_user_id,
    upper(status) as status,
    upper(detailed_status) as detailed_status,
    nullif(trim(error_code), '') as error_code,
    nullif(trim(reason), '') as reason,
    upper(type) as payment_type,
    try_cast(total_intents as integer) as total_intents,
    nullif(trim(location_of_request_state_code), '') as location_of_request_state_code,
    lower(trim(has_dispute_chargeback)) = 'true' as has_dispute_chargeback,
    try_cast(created_at as timestamptz) as created_at,
    try_cast(updated_at as timestamptz) as updated_at,
    _source_file,
    _loaded_at
from deduped
