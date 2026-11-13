-- Failure is the FAILED bucket only. CANCELLED stays out of failure_rate:
-- a cancel is not a payout error, and counting it would reorder the ranking.
select
    disbursement_provider,
    count(*) as attempts,
    count(*) filter (where is_failed_disbursement) as failed,
    count(*) filter (where disbursement_outcome = 'CANCELLED') as cancelled,
    count(*) filter (where disbursement_outcome = 'SUCCESS') as succeeded,
    failed::double / nullif(attempts, 0) as failure_rate
from {{ ref('int_remittances') }}
where disbursement_provider is not null
group by disbursement_provider
order by failed desc, failure_rate desc
