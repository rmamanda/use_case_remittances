-- Grain: one row per receipt (payment and disbursement linked on receipt).
-- Months are cut in UTC so the totals do not move with the server timezone.
-- Flags coalesce to false: the payout join can miss.
select
    receipts.receipt_id,
    receipts.payment_id,
    receipts.disbursement_id,
    receipts.sender_user_id,
    receipts.beneficiary_id,
    receipts.destination_country_code,
    receipts.destination_currency,
    receipts.amount_charged,
    receipts.fee,
    receipts.exchange_rate,
    receipts.promotion_amount,
    receipts.destination_amount,
    receipts.created_at as remittance_created_at,
    date_trunc('month', receipts.created_at at time zone 'UTC') as remittance_month,
    payments.amount as payment_amount,
    payments.currency as payment_currency,
    payments.status as payment_status,
    payments.payment_type,
    payments.has_dispute_chargeback,
    disbursements.disbursement_provider,
    disbursements.payer_destination_name as payout_destination_name,
    disbursements.status as disbursement_status,
    disbursements.disbursement_outcome,
    disbursements.amount as disbursement_amount,
    disbursements.destination_country as disbursement_destination_country,
    coalesce(
        payments.status = '{{ var("payment_status_successful") }}'
            and disbursements.disbursement_outcome = '{{ var("disbursement_outcome_success") }}',
        false
    ) as is_completed_remittance,
    payments.status = '{{ var("payment_status_successful") }}' as is_successful_payment,
    coalesce(disbursements.disbursement_outcome = 'FAILED', false) as is_failed_disbursement
from {{ ref('stg_receipts') }} as receipts
inner join {{ ref('stg_payments') }} as payments
    on receipts.payment_id = payments.payment_id
left join {{ ref('stg_disbursements') }} as disbursements
    on receipts.disbursement_id = disbursements.disbursement_id
