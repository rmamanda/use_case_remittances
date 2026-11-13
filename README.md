# use_case_remittances

Remittance pipeline on the three assignment extracts. DuckDB so it runs locally. Run the loader once, then `dbt build` for transforms and tests.

A remittance is a receipt: it carries the amount the customer was charged and points at both the payment that collected the money and the payout that delivered it. That is the grain most of this is built on, and the charge has a fact of its own.

## Run

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -U pip setuptools wheel
pip install -r requirements.txt
python scripts/load_raw.py         # writes the raw schema
dbt deps --profiles-dir .
dbt build --profiles-dir .         # transforms and tests
```

Put `payments.csv`, `receipts.csv`, and `disbursements.csv` in `data/raw/` (from the assignment data link; not in this repo). They are gitignored. Copy `profiles.example.yml` to `profiles.yml` if you do not already have one.

Two steps, on purpose. dbt transforms; it does not ingest. The loader writes `raw.payments`, `raw.receipts` and `raw.disbursements`, and dbt reads them as sources.

## Data model

| Layer | Schema | What it is |
|---|---|---|
| `scripts/load_raw.py` | `raw` | the loader, outside dbt, all text, no seeds |
| `models/staging` | `staging` | one row per id, types applied, provider statuses bucketed |
| `models/intermediate` | `intermediate` | the two facts: one row per receipt, one row per payment |
| `models/marts` | `marts` | one table per metric |

Three rules hold the shape.

**Two grains, two facts.** `int_remittances` is one row per receipt, which is the remittance. `int_payments` is one row per payment, which is the charge. A payment can carry up to 8 receipts here, so the two are not interchangeable: volume sent is counted on the first, anything belonging to the charge on the second.

**Every join in the project lives in those two models.** Receipts take payments on an inner join and payouts on a left join, so a receipt with no payout survives instead of vanishing. Payments take their receipts rolled up, so the gap between charged and booked is a column rather than a query.

**Marts aggregate one fact and never join.** A mart that needs two grains is a sign the fact is wrong, not the mart. Facts and marts both carry an enforced contract, so neither shape can drift without the build saying so.

Every run is a full load. `load_raw.py` reads the three CSVs; `dbt build` rebuilds every model and runs every test, which is the right shape for a 680MB extract on a laptop and the wrong one for production.

## Metric definitions

Six metrics from the brief, plus one I added. Thresholds are vars in `dbt_project.yml`, not literals buried in SQL.

Three of them lean on the same idea, so it is defined once. A **completed remittance** is a payment with status `SUCCESSFUL` whose payout is in the SUCCESS bucket: `PAID`, `SUCCESS`, `COMPLETED`, `DELIVERED`, `WIRE_RELEASED`, `WIRE_CONFIRMED`.

| Metric | Mart | Definition |
|---|---|---|
| Total transacted by month | `mart_monthly_transaction_volume` | `sum(amount_charged)` over receipts whose payment is `SUCCESSFUL`, bucketed by receipt `created_at` in UTC |
| Users holding 50% of volume | `mart_users_top_half_volume` | Senders ranked by completed volume. Flagged while the volume ranked above them is still under half the total, so the sender who crosses the line is included. `pareto_volume_share` 0.5 |
| Recurring customers | `mart_recurring_customers` | **At least 3 completed remittances, spread across at least 2 different months.** A burst inside one month is not recurrence. `recurring_min_remittances` 3, `recurring_min_months` 2 |
| Providers by failed payouts | `mart_provider_disbursement_failures` | `failed / attempts`, where failed is the FAILED bucket: `FAILED`, `REJECTED`, `ERROR_SENDING_PAYOUT_REQUEST`, `PAYOUT_NOT_PROCESSED`. Cancels get their own column and stay out of the rate |
| Clusters of senders on one beneficiary | `mart_beneficiary_sender_clusters` | Senders grouped by `beneficiary_id` over every remittance, delivered or not, flagged at two or more and named in `sender_ids` when there are. Delivery is not part of the question, so it is not part of the filter. Nothing clusters in this file |
| Chargeback rate | `mart_chargeback_rate` | Disputed payments over `SUCCESSFUL` payments, by the payment's own month. Reads the payment fact: the dispute belongs to the charge, and 1,961 successful payments never produced a receipt |
| Senders on one payout destination | `mart_shared_payout_destinations` | Not in the brief. Senders grouped by `payer_destination_name` and country, which is the cut that does cluster. Same population rule as the mart above |

The two flag marts return the whole population with a boolean on it, not the filtered subset. Filter on `is_recurring_customer` or `in_top_half_volume`; the denominator is already sitting there if you want the share.

## Data quality

Six things in the extract that the model takes a position on.

**1,961 successful payments never produced a receipt.** They show up in `int_payments` with `receipt_count` 0 and do not exist at all in `int_remittances`. One of them carries a dispute, which is the reason the chargeback mart reads the payment fact instead of the receipt one.

**185 receipts point at a payout that is not in the file.** The relationship test warns instead of failing and the receipt is kept. The rows land in `dbt_test__audit`.

**2,953 receipts are charged zero, and one is charged -522.99.** 2,853 of them still pass as completed remittances, so they lift counts without lifting volume. I kept them. The book should match the source, and dropping rows is the business's call, not the warehouse's. A test warns on the count and errors if it moves past 3,100. The negative one also makes the running share in the Pareto mart tip just over 1 in the tail before coming back to land on the total, which the reconciliation test checks.

**Money is `decimal`, never `double`.** These columns get summed across the whole book, and float addition is not associative: the same total came out different in the last bits depending on how the query was grouped. `payments.amount` keeps four decimals because 685 rows came through a float32 field upstream (`122.989997864` is `122.99`) and a few hundred more carry real half-cent values.

**Months are cut in UTC.** `date_trunc` on a `timestamptz` follows the session timezone, which moves about 4.8k receipts across month boundaries and makes the monthly numbers depend on where the job runs.

**The completion flags are never null.** The payout join misses on those 185 receipts, which would otherwise leave the flag null, and anyone writing `where not is_completed_remittance` would lose the rows without being told. They coalesce to false.

The three extracts have no duplicate ids at all, so the dedupe in staging does nothing today. It is there for the production shape, where the same id arrives on every run that touches it.

## Tests

`dbt build` runs 62 data tests and 3 unit tests over 12 models. `store_failures` is on, so a failing row is queryable in `dbt_test__audit` instead of only counted.

The data tests are the usual keys and relationships, plus a few that pin business rules: the recurring flag has to agree with its own thresholds, failure and chargeback rates have to land between 0 and 1, and three singular tests. One reconciles the sender ranking against the receipt fact, one checks the provider mart still covers every payout in the file, and one checks that no beneficiary takes money from two senders. Each compares a mart against its source rather than against itself: a mart that quietly loses rows stays internally consistent, so a self-check passes while the numbers are already wrong.

Keys are tested on the sources rather than only on staging. Staging dedupes on the id, so uniqueness there is true by construction and tests the macro instead of the data. The source is where a duplicate could actually turn up. `at_least_one` sits there too, because a file that loads empty passes every other assertion in the project.

The unit tests cover the three rules that are easiest to get quietly wrong:

- the provider status buckets, including that a cancel is not a failure
- the 50% boundary, with 40 + 30 + 30, where the second sender straddles the line and has to be in
- the recurring thresholds, where 3 remittances in one month is not recurrence and 2 across two months is not either

One test is a drift alarm rather than pass/fail: the zero-amount check warns at today's 2,954 and errors past 3,100. The point is being told when the number moves, not being told every run that it is not zero.

## What I would take to the business

The extract runs from 31 Dec 2025 through 22 Sep 2026. September is partial. August is the last full month and the high: about 103k successful-payment receipts and $34.0M booked.

**Booked value is not cash collected.** Monthly volume sums `receipts.amount_charged` on payments with status `SUCCESSFUL`. The grain is the receipt, because that is the remittance. 13,215 payments have between 2 and 8 receipts. On those, the receipt sums average about $1,018 against a payment amount of about $462, and they almost never match. I did not collapse to the payment. Finance, if they want money taken from the customer, has to sum `payment.amount` once per payment. The mart is the book of remittances.

**Half the delivered volume sits with 15% of senders.** 58,933 of 391,415 senders with a completed remittance account for 50% of that volume. The same population, under the recurrence rule, gives 75,495 senders, 19.3%. One-off senders are the rest of the book.

**Chargeback is not the problem in this extract.** 525 chargebacks on 724,052 successful payments, 0.073%. I would not staff a workstream off this file. I would still keep the monthly rate, because a jump from this base would matter.

**Provider rank is by failed payouts, not by cancels.** Counting cancels as failures would punish the wrong provider: PROVIDER 12 has 2,751 failures and 5,046 cancels, while PROVIDER 3 leads on failures (3,505 of 243,048 attempts, 1.44%) and has no cancels. PROVIDER 2 is the ugly rate, 7.48%, on only 3,396 attempts. I would look at that one before the big corridors.

**`beneficiary_id` is not a person we can cluster.** The question behind this one is fraud: several senders paying into a single beneficiary is the classic shape of smurfing, where one flow is broken into small pieces to stay under review thresholds. It is also what a family sharing one account looks like, which is why the mart flags rather than accuses. Every beneficiary id in this file has one sender. The cluster mart comes back flat on purpose. `payer_destination_name` does cluster (DESTINATION_17 in MX has tens of thousands of senders), and that label behaves like a payout corridor, not a beneficiary. I left it as a separate mart so nobody reads it as the answer to the brief.

## If this went to production

**The load would go incremental.** `receipts` has no `updated_at`, so the receipt is immutable and would load append-only on `created_at`. `payments` and `disbursements` both carry `updated_at` and their status moves after the fact, so they would load with a merge on `id` and a watermark on `updated_at`, wide enough to catch a payout that sits in `PAYABLE` for a week before it settles. The fact appends; the two mutable tables merge.

**The ids would be tagged.** They are already 64-character hashes, but I would still mark `sender_user_id` and `beneficiary_id` as pseudonymous and keep the raw schema off the BI role. There is no name, email, or account number in the extract.

**Status history would need a snapshot.** Staging holds the latest row per id and the earlier states are gone, so "how long until the money lands" is not answerable from this model. A snapshot on the two mutable tables fixes it, and a single extract has nothing to snapshot yet.
