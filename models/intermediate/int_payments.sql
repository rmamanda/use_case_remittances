-- Grain: one row per payment. The charge, not the remittance.
-- Receipts roll up here, so the gap between charged and booked is a column.
with receipts as (
    select
        payment_id,
        count(*) as receipt_count,
        sum(amount_charged) as receipts_amount_charged
    from {{ ref('stg_receipts') }}
    group by payment_id
)

select
    payments.payment_id,
    payments.sender_user_id,
    payments.amount as payment_amount,
    payments.currency as payment_currency,
    payments.status as payment_status,
    payments.detailed_status,
    payments.payment_type,
    payments.has_dispute_chargeback,
    payments.created_at as payment_created_at,
    date_trunc('month', payments.created_at at time zone 'UTC') as payment_month,
    coalesce(receipts.receipt_count, 0) as receipt_count,
    receipts.receipts_amount_charged,
    payments.status = '{{ var("payment_status_successful") }}' as is_successful_payment
from {{ ref('stg_payments') }} as payments
left join receipts
    on payments.payment_id = receipts.payment_id
