{% macro generate_schema_name(custom_schema_name, node) -%}
    {#
      Medallion: use layer names as schema names (raw, snapshots, silver, gold).
      No target_schema prefix so we get exact names in all environments.
    #}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
