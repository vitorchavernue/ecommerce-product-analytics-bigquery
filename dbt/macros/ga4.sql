{#-
  Cross-database helpers.
  The GA4 export stores data in nested lists (event parameters, products). BigQuery and DuckDB read
  them with slightly different syntax, so every model calls these macros instead of writing the
  syntax directly. Result: one set of models, two engines (BigQuery in production, DuckDB in CI).
-#}

{#- True when the SQL must be written for BigQuery.
    `render_bigquery_sql` lets CI compile the BigQuery version of every model without a Google account
    (the compiled SQL is then checked by a BigQuery syntax parser). -#}
{% macro is_bigquery() -%}
    {{ return(target.type == 'bigquery' or var('render_bigquery_sql', false)) }}
{%- endmacro %}

{#- Read one event parameter (e.g. ga_session_id) from the list of key / value pairs.
    value_type: string, int, double -#}
{% macro event_param(key, value_type='string') -%}
    {%- if is_bigquery() -%}
        (select ep.value.{{ value_type }}_value from unnest(event_params) as ep where ep.key = '{{ key }}' limit 1)
    {%- else -%}
        (select ep.value.{{ value_type }}_value from unnest(event_params) as t(ep) where ep.key = '{{ key }}' limit 1)
    {%- endif -%}
{%- endmacro %}

{#- One row per product inside an event (FROM clause continuation). -#}
{% macro unnest_items(alias='item') -%}
    {%- if is_bigquery() -%}
        cross join unnest(items) as {{ alias }}
    {%- else -%}
        cross join unnest(items) as u({{ alias }})
    {%- endif -%}
{%- endmacro %}

{#- Only read the days inside the analysis window.
    On BigQuery this uses the daily table suffix, so days outside the window are not even scanned (and not billed). -#}
{% macro ga4_date_filter() -%}
    {%- if is_bigquery() -%}
        _table_suffix between '{{ var("start_date") }}' and '{{ var("end_date") }}'
    {%- else -%}
        event_date between '{{ var("start_date") }}' and '{{ var("end_date") }}'
    {%- endif -%}
{%- endmacro %}

{#- event_date comes as text 'YYYYMMDD' -#}
{% macro parse_yyyymmdd(column) -%}
    {%- if is_bigquery() -%}
        parse_date('%Y%m%d', {{ column }})
    {%- else -%}
        cast(strptime({{ column }}, '%Y%m%d') as date)
    {%- endif -%}
{%- endmacro %}

{#- timestamps come as integers: microseconds since 1970 (UTC) -#}
{% macro micros_to_timestamp(column) -%}
    {%- if is_bigquery() -%}
        timestamp_micros({{ column }})
    {%- else -%}
        make_timestamp({{ column }})
    {%- endif -%}
{%- endmacro %}

{#- whole days from start_date to end_date -#}
{% macro days_between(start_date, end_date) -%}
    {%- if is_bigquery() -%}
        date_diff({{ end_date }}, {{ start_date }}, day)
    {%- else -%}
        date_diff('day', {{ start_date }}, {{ end_date }})
    {%- endif -%}
{%- endmacro %}

{#- Monday of the week (ISO week) -#}
{% macro week_start(column) -%}
    {%- if is_bigquery() -%}
        date_trunc({{ column }}, isoweek)
    {%- else -%}
        cast(date_trunc('week', {{ column }}) as date)
    {%- endif -%}
{%- endmacro %}

{#- a literal date, e.g. '2021-02-01' -#}
{% macro date_literal(value) -%}
    date '{{ value }}'
{%- endmacro %}

{#- The value of `column` in the earliest row (by `order_by`) of the group, ignoring empty values.
    Used for "landing page" or "source of the first event of the visit". -#}
{% macro first_value_by(column, order_by) -%}
    {%- if is_bigquery() -%}
        array_agg({{ column }} ignore nulls order by {{ order_by }} limit 1)[safe_offset(0)]
    {%- else -%}
        arg_min({{ column }}, {{ order_by }}) filter (where {{ column }} is not null)
    {%- endif -%}
{%- endmacro %}

{#- division that returns null instead of an error when the denominator is zero -#}
{% macro safe_div(numerator, denominator) -%}
    case when coalesce({{ denominator }}, 0) = 0 then null else ({{ numerator }}) * 1.0 / ({{ denominator }}) end
{%- endmacro %}
