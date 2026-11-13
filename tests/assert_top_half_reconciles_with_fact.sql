-- Fails when the ranking stops reconciling with the receipt fact: a sender went missing,
-- the volume drifted, or the running sum stopped landing on the fact's own total.
with from_fact as (
    select
        count(distinct sender_user_id) as senders,
        sum(amount_charged) as volume
    from {{ ref('int_remittances') }}
    where is_completed_remittance
),

from_mart as (
    select
        count(*) as senders,
        sum(total_amount_charged) as volume,
        max(platform_total_volume) as platform_total,
        arg_max(cumulative_volume, volume_rank) as last_cumulative
    from {{ ref('mart_users_top_half_volume') }}
)

select
    from_fact.senders as fact_senders,
    from_mart.senders as mart_senders,
    from_fact.volume as fact_volume,
    from_mart.volume as mart_volume,
    from_mart.platform_total,
    from_mart.last_cumulative
from from_fact, from_mart
where from_fact.senders is distinct from from_mart.senders
    or from_fact.volume is distinct from from_mart.volume
    or from_fact.volume is distinct from from_mart.platform_total
    or from_fact.volume is distinct from from_mart.last_cumulative
