{% snapshot accounts_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='account_id',
      strategy='timestamp',
      updated_at='updated_at',
    )
}}

select * from {{ ref('raw_accounts') }}

{% endsnapshot %}
