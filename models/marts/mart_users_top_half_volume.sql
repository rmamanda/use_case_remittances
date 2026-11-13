with user_volume as (
    select
        sender_user_id,
        sum(amount_charged) as total_amount_charged,
        count(*) as remittance_count
    from {{ ref('int_remittances') }}
    where is_completed_remittance
    group by sender_user_id
),

ranked as (
    select
        *,
        sum(total_amount_charged) over () as platform_total_volume,
        row_number() over (order by total_amount_charged desc, sender_user_id) as volume_rank,
        sum(total_amount_charged) over (
            order by total_amount_charged desc, sender_user_id
            rows between unbounded preceding and current row
        ) as cumulative_volume
    from user_volume
)

select
    sender_user_id,
    total_amount_charged,
    remittance_count,
    volume_rank,
    cumulative_volume,
    platform_total_volume,
    cumulative_volume / nullif(platform_total_volume, 0) as share_of_total_volume,
    (cumulative_volume - total_amount_charged)
        < platform_total_volume * {{ var('pareto_volume_share') }} as in_top_half_volume
from ranked
order by volume_rank
