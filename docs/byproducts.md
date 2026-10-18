# Persisted Pulverizer byproducts

New iron-processing jobs now produce two iron dust and have the pinned recipe's
10% chance of one nickel dust. The byproduct has its own output slot and cannot
be inserted by ordinary player inventory callbacks. Both potential output slots
must have room before paid work starts or continues.

Job schema 3 saves the source secondary item/count, chance and a percentile
result from 1..100 when RF is first spent. Blocking an output and clean SQLite
restarts preserve that exact decision. A winning result commits primary and
secondary outputs together with the single reserved input, without yielding.
No RF, item or random draw is consumed before output-capacity preflight.

Older four-field fixed jobs and schema-2 dynamic primary-only jobs retain their
saved behavior. They do not gain a byproduct when the code changes; the next
new job uses schema 3. Existing schema-2 machine state remains supported; the
extra output slot is added only on valid processing when needed. Malformed
secondary records pause before inventory/RF mutation.

The original unaugmented TE class checks room for potential outputs and rolls
its chance at completion. Golden Era deliberately chooses and saves at paid-work
start so it cannot reroll after blocking/restart. The baseline distribution is
preserved; the original RNG timing/sequence is not claimed. The exact class/hash
and reviewed methods are recorded in `thermal-runtime-review.json`; chance and
native material mapping are compiled from the pinned recipe/specification.

Engine tests force winning and losing pending jobs through blocked outputs and
two restarts, preserve a preexisting schema-2 job, enumerate all 100 percentile
outcomes (exactly ten wins), and reject eight malformed secondary records.
Forced-crash atomicity remains outside this transaction model. Augments, ore
variants and automated byproduct routing are separate work.
