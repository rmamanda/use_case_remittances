with by_month as (
    select
        sender_user_id,
        remittance_month as activity_month,
        count(*) as n
    from {{ ref('int_remittances') }}
    where is_completed_remittance
    group by sender_user_id, activity_month
)

select
    sender_user_id,
    sum(n) as completed_remittances,
    count(*) as months_active,
    count(*) >= {{ var('recurring_min_months') }}
        and sum(n) >= {{ var('recurring_min_remittances') }} as is_recurring_customer
from by_month
group by sender_user_id
