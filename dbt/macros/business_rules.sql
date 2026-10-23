{#-
  Business rules shared by several models: how a visit is assigned to a marketing channel,
  and how the uncertainty of a conversion rate is measured.
-#}

{#- Marketing channel of a visit, from its source and medium (GA4 default channel grouping, simplified).
    The public sample hides part of the values as '<Other>' or '(data deleted)': those visits are
    kept, but reported as 'Unattributed' instead of being guessed. -#}
{% macro channel_group(source, medium) -%}
    case
        when {{ medium }} is null or {{ source }} is null then 'Unattributed'
        when {{ medium }} in ('<Other>', '(data deleted)') or {{ source }} in ('<Other>', '(data deleted)') then 'Unattributed'
        when {{ source }} = '(direct)' and {{ medium }} in ('(none)', '(not set)') then 'Direct'
        when {{ medium }} = 'organic' then 'Organic Search'
        when {{ medium }} in ('cpc', 'ppc', 'paidsearch') then 'Paid Search'
        when {{ medium }} in ('display', 'cpm', 'banner') then 'Display'
        when {{ medium }} in ('email', 'e-mail') then 'Email'
        when {{ medium }} = 'affiliate' then 'Affiliates'
        when {{ medium }} = 'referral' then 'Referral'
        else 'Other'
    end
{%- endmacro %}

{#- 95% Wilson confidence interval of a rate (successes / trials).
    It answers "how sure are we about this conversion rate?": a channel with few visits gets a wide
    interval, so a high rate on little traffic is not mistaken for a real advantage. -#}
{% macro wilson_bound(successes, trials, side='lower', z=1.96) -%}
    case when coalesce({{ trials }}, 0) = 0 then null else
        (
            ({{ successes }}) * 1.0 / ({{ trials }}) + {{ z }} * {{ z }} / (2.0 * ({{ trials }}))
            {{ '-' if side == 'lower' else '+' }} {{ z }} * sqrt(
                (({{ successes }}) * 1.0 / ({{ trials }})) * (1 - ({{ successes }}) * 1.0 / ({{ trials }})) / ({{ trials }})
                + {{ z }} * {{ z }} / (4.0 * ({{ trials }}) * ({{ trials }}))
            )
        ) / (1 + {{ z }} * {{ z }} / ({{ trials }}))
    end
{%- endmacro %}

{#- Two-proportion z statistic: is the conversion of a segment different from the rest of the traffic?
    |z| above 1.96 means the difference is statistically significant at the 5% level. -#}
{% macro two_proportion_z(successes_a, trials_a, successes_b, trials_b) -%}
    case when coalesce({{ trials_a }}, 0) = 0 or coalesce({{ trials_b }}, 0) = 0 then null else
        (
            ({{ successes_a }}) * 1.0 / ({{ trials_a }}) - ({{ successes_b }}) * 1.0 / ({{ trials_b }})
        ) / nullif(sqrt(
            (({{ successes_a }}) + ({{ successes_b }})) * 1.0 / (({{ trials_a }}) + ({{ trials_b }}))
            * (1 - (({{ successes_a }}) + ({{ successes_b }})) * 1.0 / (({{ trials_a }}) + ({{ trials_b }})))
            * (1.0 / ({{ trials_a }}) + 1.0 / ({{ trials_b }}))
        ), 0)
    end
{%- endmacro %}
