{#-
  Weekly retention of new users.
  Users are grouped by the week of their first visit (cohort). For each following week we count how
  many of them came back. Week 0 is always 100%. Weeks that run past the end of the data are flagged
  as incomplete, so the heatmap does not show a false drop at the end.
-#}
with users as (

    select user_pseudo_id, {{ week_start('first_seen_date') }} as cohort_week
    from {{ ref('dim_users') }}
    where is_new_in_window
      -- only full weeks: a cohort that starts before the first day of data would be incomplete
      and {{ week_start('first_seen_date') }} >= {{ parse_yyyymmdd("'" ~ var('start_date') ~ "'") }}

),

activity as (

    select distinct
        s.user_pseudo_id,
        u.cohort_week,
        cast(floor({{ days_between('u.cohort_week', week_start('s.session_date')) }} / 7) as {{ dbt.type_int() }}) as week_number
    from {{ ref('fct_sessions') }} as s
    join users as u on u.user_pseudo_id = s.user_pseudo_id

),

cohort_size as (

    select cohort_week, count(*) as cohort_users from users group by cohort_week

),

last_week as (

    select {{ week_start(parse_yyyymmdd("'" ~ var('end_date') ~ "'")) }} as last_data_week

)

select
    a.cohort_week,
    a.week_number,
    c.cohort_users,
    count(distinct a.user_pseudo_id)                                          as active_users,
    count(distinct a.user_pseudo_id) * 1.0 / c.cohort_users                   as retention_rate,
    {{ days_between('a.cohort_week', 'l.last_data_week') }} / 7 >= a.week_number as is_complete_week
from activity as a
join cohort_size as c on c.cohort_week = a.cohort_week
cross join last_week as l
where a.week_number between 0 and {{ var('retention_weeks') }}
group by a.cohort_week, a.week_number, c.cohort_users, l.last_data_week
