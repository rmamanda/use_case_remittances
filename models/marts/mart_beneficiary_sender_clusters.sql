with pairs as (
    select
        beneficiary_id,
        sender_user_id,
        count(*) as remittance_count,
        count(*) filter (where is_completed_remittance) as completed_remittance_count,
        sum(amount_charged) as total_amount_charged,
        sum(amount_charged) filter (where is_completed_remittance) as completed_amount_charged
    from {{ ref('int_remittances') }}
    group by beneficiary_id, sender_user_id
)

select
    beneficiary_id,
    count(*) as sender_count,
    case
        when count(*) >= 2 then list(sender_user_id order by sender_user_id)
    end as sender_ids,
    sum(remittance_count) as remittance_count,
    sum(completed_remittance_count) as completed_remittance_count,
    coalesce(sum(total_amount_charged), 0) as total_amount_charged,
    coalesce(sum(completed_amount_charged), 0) as completed_amount_charged,
    count(*) >= 2 as multiple_senders
from pairs
group by beneficiary_id
order by sender_count desc, completed_amount_charged desc
