-- Every event with a session id must belong to a visit in fct_sessions (no visit lost in the grouping).
select distinct e.session_key
from {{ ref('stg_ga4__events') }} as e
left join {{ ref('fct_sessions') }} as s on s.session_key = e.session_key
where e.session_key is not null and s.session_key is null
