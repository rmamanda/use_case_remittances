{#- order_by is an expression, not a column name: raw is all-varchar, so callers cast it. -#}
{% macro dedupe_latest(relation, partition_by, order_by) %}
(
    select *
    from {{ relation }}
    qualify row_number() over (
        partition by {{ partition_by }}
        order by {{ order_by }} desc nulls last
    ) = 1
)
{% endmacro %}
