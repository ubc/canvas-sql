CREATE OR REPLACE VIEW account_hierarchy_vw

WITH RECURSIVE account_hierarchy (
    root_account_id,
    root_account,
    subaccount1_id,
    subaccount1,
    subaccount2_id,
    subaccount2,
    subaccount3_id,
    subaccount3,
    subaccount4_id,
    subaccount4,
    subaccount5_id,
    subaccount5,
    id,
    name,
    workflow_state,
    level
) AS (
    -- Anchor member: start with root accounts
    SELECT
        id AS root_account_id,
        name AS root_account,
        CAST(NULL AS BIGINT) AS subaccount1_id,
        CAST(NULL AS VARCHAR) AS subaccount1,
        CAST(NULL AS BIGINT) AS subaccount2_id,
        CAST(NULL AS VARCHAR) AS subaccount2,
        CAST(NULL AS BIGINT) AS subaccount3_id,
        CAST(NULL AS VARCHAR) AS subaccount3,
        CAST(NULL AS BIGINT) AS subaccount4_id,
        CAST(NULL AS VARCHAR) AS subaccount4,
        CAST(NULL AS BIGINT) AS subaccount5_id,
        CAST(NULL AS VARCHAR) AS subaccount5,
        id AS id,
        name AS name,
        workflow_state AS workflow_state,
        0 AS level
    FROM
        accounts
    WHERE
        parent_account_id IS NULL

    UNION ALL

    -- Recursive member: join with itself to traverse the hierarchy
    SELECT
        ah.root_account_id,
        ah.root_account,
        CASE WHEN ah.level = 0 THEN a.id ELSE ah.subaccount1_id END AS subaccount1_id,
        CASE WHEN ah.level = 0 THEN a.name ELSE ah.subaccount1 END AS subaccount1,
        CASE WHEN ah.level = 1 THEN a.id ELSE ah.subaccount2_id END AS subaccount2_id,
        CASE WHEN ah.level = 1 THEN a.name ELSE ah.subaccount2 END AS subaccount2,
        CASE WHEN ah.level = 2 THEN a.id ELSE ah.subaccount3_id END AS subaccount3_id,
        CASE WHEN ah.level = 2 THEN a.name ELSE ah.subaccount3 END AS subaccount3,
        CASE WHEN ah.level = 3 THEN a.id ELSE ah.subaccount4_id END AS subaccount4_id,
        CASE WHEN ah.level = 3 THEN a.name ELSE ah.subaccount4 END AS subaccount4,
        CASE WHEN ah.level = 4 THEN a.id ELSE ah.subaccount5_id END AS subaccount5_id,
        CASE WHEN ah.level = 4 THEN a.name ELSE ah.subaccount5 END AS subaccount5,
        a.id AS id,
        a.name AS name,
        a.workflow_state as workflow_state,
        ah.level + 1 AS level
    FROM
        account_hierarchy ah
    JOIN
        accounts a ON a.parent_account_id = ah.id
    WHERE
        ah.level < 5 -- (the level is still subaccount+1 here) Limit to 5 subaccount levels (subaccount1, subaccount2, subaccount3 ...)
)


SELECT * FROM account_hierarchy