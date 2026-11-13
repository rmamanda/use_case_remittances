select
    remittance_month as transaction_month,
    count(*) as remittance_count,
    count(distinct sender_user_id) as active_senders,
    sum(amount_charged) as total_amount_charged,
    sum(case when is_completed_remittance then amount_charged else 0 end) as completed_amount_charged,
    sum(case when is_completed_remittance then 1 else 0 end) as completed_remittance_count
from {{ ref('int_remittances') }}
where is_successful_payment
group by transaction_month
order by transaction_month
