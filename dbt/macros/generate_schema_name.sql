{#- Use the dataset names exactly as configured (ga4_staging, ga4_core, ga4_reporting),
    instead of dbt's default "<target dataset>_<custom>" prefix. -#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}{{ target.schema }}{%- else -%}{{ custom_schema_name | trim }}{%- endif -%}
{%- endmacro %}
