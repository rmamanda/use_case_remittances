-- Provider status strings are inconsistent in the export; bucketed below for joins/metrics.
with deduped as {{ dedupe_latest(source('remittances', 'disbursements'), 'id', 'try_cast(updated_at as timestamptz)') }}

select
    id as disbursement_id,
    user_id as sender_user_id,
    upper(type) as disbursement_type,
    upper(status) as status,
    upper(raw_status) as raw_status,
    nullif(trim(provider_status), '') as provider_status,
    try_cast(amount as decimal(18, 2)) as amount,
    disbursement_provider,
    payer_destination_name,
    upper(destination_country) as destination_country,
    upper(destination_currency) as destination_currency,
    try_cast(created_at as timestamptz) as created_at,
    try_cast(updated_at as timestamptz) as updated_at,
    case
        when upper(status) in (
            'PAID', 'SUCCESS', 'COMPLETED', 'DELIVERED', 'WIRE_RELEASED', 'WIRE_CONFIRMED'
        ) then 'SUCCESS'
        when upper(status) in (
            'FAILED', 'REJECTED', 'ERROR_SENDING_PAYOUT_REQUEST', 'PAYOUT_NOT_PROCESSED'
        ) then 'FAILED'
        when upper(status) in ('CANCELLED', 'CANCELLATION_IN_PROGRESS') then 'CANCELLED'
        else 'OTHER'
    end as disbursement_outcome,
    _source_file,
    _loaded_at
from deduped
