-- Fails when a payout is missing from the provider mart because no receipt points at it.
with counted as (
    select
        (select sum(attempts) from {{ ref('mart_provider_disbursement_failures') }}) as in_mart,
        (select count(*) from {{ ref('stg_disbursements') }}
         where disbursement_provider is not null) as in_staging
)

select *
from counted
where in_mart <> in_staging
