select
    payment_month as transaction_month,
    count(*) as successful_payments,
    count(*) filter (where has_dispute_chargeback) as chargeback_payments,
    count(*) filter (where has_dispute_chargeback)::double
        / nullif(count(*), 0) as chargeback_rate
from {{ ref('int_payments') }}
where is_successful_payment
group by payment_month
order by payment_month
