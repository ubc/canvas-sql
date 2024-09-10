

WITH course_modules AS (
    --- get the course modules for a course
    --- the context_id == the course_id
    SELECT 
        context_id AS course_id,
        id AS module_id,
        position AS module_position,
        name AS module_name,
        workflow_state AS module_workflow_state,
        created_at AS module_created_at,
        unlock_at AS module_unlock_at,
        completion_events AS module_completion_events, --- why is this empty?
        require_sequential_progress AS module_require_sequential,
        requirement_count AS module_requirement_count, 
        prerequisites AS module_prerequisites,
        completion_requirements AS module_completion_requirements
    FROM context_modules
    WHERE context_id IN ({COURSE_ID})  --- REQUIRED: the context_id is the course_id or list of course_ids 10456 is a Sandbox course with module progress setup for testing 
    AND context_type = 'Course'
    AND workflow_state != 'deleted'
    ORDER BY module_position
),

enrolled_active_users AS (
    SELECT 
        DISTINCT
            course_id,
            user_id 
    FROM enrollments 
    WHERE course_id IN (SELECT DISTINCT course_id FROM course_modules)  
    AND workflow_state != 'deleted'
    AND type = 'StudentEnrollment'
), 


extended_module_requirements AS (
-- for the course, for the module 
-- tells us which module_items have requirements and what those requirements are 
-- DOES NOT tell us the scores if requirement is score based (TODO could parse this)
-- DOES NOT INCLUDE modules with no requirements
    SELECT 
        course_id,
        module_id,
        CAST(json_extract_scalar(requirement, '$.id') AS BIGINT) AS requirement__item_id,
        json_extract_scalar(requirement, '$.type') AS requirement_type,
        json_extract_scalar(requirement, '$.min_score') AS requirement_min_score
    FROM course_modules
    CROSS JOIN UNNEST(
        CAST(json_parse(course_modules.module_completion_requirements) AS ARRAY<JSON>)
    ) AS t (requirement) 
),


module_items_with_requirements AS (
-- for each module 
-- tells us the items
-- indicates the requirement status of the item 
    SELECT 
        content_tags.context_id AS course_id,
        context_module_id AS module_id,
        id AS item_id,
        workflow_state AS item_workflow_state,
        content_id AS item_content_id,
        position AS item_position,
        content_type AS item_content_type,
        url as item_url, --- note, this is not the page url 
        title as item_title,
        extended_module_requirements.requirement_type AS item_requirement,
        extended_module_requirements.requirement_min_score AS item_requirement_min_score
    FROM content_tags 
    LEFT JOIN extended_module_requirements ON content_tags.context_id = extended_module_requirements.course_id --bigint
        AND content_tags.id = extended_module_requirements.requirement__item_id
    WHERE tag_type = 'context_module'
    AND workflow_state != 'deleted'
    AND context_module_id IN (
        SELECT DISTINCT module_id FROM course_modules
    )
),

module_items_with_requirements_and_users AS (
-- table with all modules, module item requirements and active ("not deleted") course users
    SELECT 
        module_items_with_requirements.*,
        enrolled_active_users.user_id
    FROM module_items_with_requirements
    LEFT JOIN enrolled_active_users 
        ON module_items_with_requirements.course_id = enrolled_active_users.course_id 
),



user_module_completion AS (
-- for each module that has requirements 
-- tells us the completion status of the module 
-- only for active users 
    SELECT 
        course_modules.course_id,
        course_modules.module_id, 
        user_id,
        id AS progression_id,
        workflow_state AS module_completion_state,
        completed_at, 
        requirements_met,
        incomplete_requirements, -- for minscore tells us the current score if not met
        current,
        current_position
    FROM course_modules
    JOIN context_module_progressions 
        ON course_modules.module_id = context_module_progressions.context_module_id
    WHERE context_module_progressions.context_module_id IN (SELECT DISTINCT module_id FROM course_modules ) --TODO this query is slow - does this speed it up? 
    AND user_id IN (SELECT DISTINCT user_id FROM enrolled_active_users)
    ORDER BY course_id, user_id, module_id
),


extended_requirements_met AS (
-- tells us the status per user of requirements that have been met
    SELECT 
        course_id,
        module_id,
        user_id,
        progression_id,
        module_completion_state,
        completed_at,
        CAST(json_extract_scalar(requirement, '$.id') AS BIGINT) AS requirement_met__item_id
    FROM user_module_completion
    LEFT JOIN UNNEST(
        CAST(json_parse(user_module_completion.requirements_met) AS ARRAY<JSON>)
    ) AS t (requirement) ON TRUE
),

extended_requirements_not_met AS (
-- tells us the status per user of requirements that have not been met (min score only)
    SELECT 
        course_id,
        module_id,
        user_id,
        progression_id,
        module_completion_state,
        completed_at,
        CAST(json_extract_scalar(requirement, '$.id') AS BIGINT) AS requirement_not_met__item_id,
        json_extract_scalar(requirement, '$.score') AS requirement_not_met__current_score
    FROM user_module_completion
    LEFT JOIN UNNEST(
        CAST(json_parse(user_module_completion.incomplete_requirements) AS ARRAY<JSON>)
    ) AS t (requirement) ON TRUE
),

full_course_structure_with_module_and_item_status AS (
    SELECT 
        course_modules.course_id,
        course_modules.module_id,
        course_modules.module_position,
        course_modules.module_name,
        course_modules.module_workflow_state,
        course_modules.module_unlock_at,
        mi_structure.item_position,
        mi_structure.item_id, -- this should be the module_item_id 
        mi_structure.item_content_type,
        mi_structure.item_content_id, -- this should be the id based on the type of item, i.e item_content_type = 'Assignment' then this is the assignment id Note: this is 0 for subheaders and for external urls (these things can only exist as module items)
        mi_structure.item_workflow_state,
      --  mi_structure.item_url,
        mi_structure.item_title,
        CASE WHEN mi_structure.item_requirement = 'min_score' THEN 
            concat(mi_structure.item_requirement, ': ', mi_structure.item_requirement_min_score)
            ELSE mi_structure.item_requirement END 
            AS item_requirement,
        -- mi_structure.item_requirement_min_score,
        mi_structure.user_id, 
        users.name AS user_name,
        module_completion.progression_id AS user_progression_id,
        module_completion.module_completion_state AS user_module_state,
        module_completion.completed_at AS user_module_completed_at,
        CASE WHEN mi_structure.item_requirement IS null THEN null -- if there is no requirement 
            WHEN mi_structure.item_requirement IS NOT null 
                AND item_requirements_met.requirement_met__item_id IS null THEN false -- if there is a requirement but nothing met 
            ELSE true END
            AS user_met_item_requirement
        -- item_requirements_not_met.requirement_not_met__current_score AS user_item_not_met_current_score
    FROM course_modules 
    LEFT JOIN module_items_with_requirements_and_users AS mi_structure -- get the full structure of the course modules 
        ON course_modules.module_id = mi_structure.module_id
        AND course_modules.course_id = mi_structure.course_id
    LEFT JOIN user_module_completion AS module_completion ON  -- get the status of module completion for each module / user 
        course_modules.module_id = module_completion.module_id
        AND mi_structure.user_id = module_completion.user_id 
    LEFT JOIN extended_requirements_met AS item_requirements_met -- get the list of item requirements complete per user
        ON mi_structure.course_id = item_requirements_met.course_id 
        AND mi_structure.module_id = item_requirements_met.module_id 
        AND mi_structure.user_id = item_requirements_met.user_id
        AND mi_structure.item_id = item_requirements_met.requirement_met__item_id
    LEFT JOIN extended_requirements_not_met AS item_requirements_not_met -- get the current score of item it not met requirement
        ON mi_structure.course_id = item_requirements_not_met.course_id 
        AND mi_structure.module_id = item_requirements_not_met.module_id 
        AND mi_structure.user_id = item_requirements_not_met.user_id
        AND mi_structure.item_id = item_requirements_not_met.requirement_not_met__item_id
    LEFT JOIN users ON mi_structure.user_id = users.id 
    ORDER BY user_id, course_id, module_position, item_position
)


--- apply final filters here 
SELECT * FROM full_course_structure_with_module_and_item_status
WHERE module_workflow_state = 'active' -- only active modules 
AND item_workflow_state = 'active' -- only active items 
-- AND item_requirement IS NOT null -- filter to only items that have a requirement 
-- AND module_completion_state = 'completed' -- filter to only modules that have been completed by certain users 
-- AND user_id IN (...) --- filter to specific users 