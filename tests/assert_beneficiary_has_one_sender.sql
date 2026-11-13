-- Fails if any beneficiary ever takes money from more than one sender.
select
    beneficiary_id,
    count(distinct sender_user_id) as senders
from {{ ref('stg_receipts') }}
group by beneficiary_id
having count(distinct sender_user_id) > 1
