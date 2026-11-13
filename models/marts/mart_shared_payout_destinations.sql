-- Not the assignment grain: groups senders who share a payout destination label,
-- which is the cut that clusters when beneficiary_id does not.
with pairs as (
    select
        payout_destination_name,
        disbursement_destination_country,
        sender_user_id,
        count(*) as remittance_count,
        count(*) filter (where is_completed_remittance) as completed_remittance_count,
        sum(amount_charged) as total_amount_charged,
        sum(amount_charged) filter (where is_completed_remittance) as completed_amount_charged
    from {{ ref('int_remittances') }}
    where payout_destination_name is not null
    group by payout_destination_name, disbursement_destination_country, sender_user_id
)

select
    payout_destination_name,
    disbursement_destination_country,
    count(*) as sender_count,
    sum(remittance_count) as remittance_count,
    sum(completed_remittance_count) as completed_remittance_count,
    coalesce(sum(total_amount_charged), 0) as total_amount_charged,
    coalesce(sum(completed_amount_charged), 0) as completed_amount_charged,
    count(*) >= 2 as multiple_senders
from pairs
group by payout_destination_name, disbursement_destination_country
order by sender_count desc, completed_amount_charged desc
