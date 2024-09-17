# Module Progress

In Canvas you can set up Module Progressions for your course. The module_progress.sql is a template sql that uses "Canvas Data 2" tables to generate an output for a course (or list of courses). This will include the entire module and module item structure, the module and item requirements, and for each user the status of the module progress. The use case assumes that you would like to return the full module structure: including unpublished modules and items, status for all students, and modules and items that may not have requirements. The results can be filtered at the end for other use cases. 

## Requirements
1. Must enter a {COURSE_ID} where indicated in the SQL
1. Written for Athena
1. At UBC uses "canvas" db 

## Fields
Field | Description | Notes
---------|----------|---------
course_id | The ID of the course. | 
module_id | The ID of the module within the course. | 
module_position | The position of the module in the course. | 
module_name | The name of the module. | 
module_workflow_state | The workflow state of the module (e.g. active, unpublished) | You could filter to only active to remove unpublished modules. 
module_unlock_at | The date and time when the module is unlocked. | 
item_position | The position of the item within the module. | 
item_id | The ID of the item within the module. | This should be the module_item_id.
item_content_type | The type of content for the item (e.g. Assignment, WikiPage) | 
item_content_id | The ID of the content based on the type of item | i.e) For Assignments, this is the assignment ID. For subheaders and external URLs the id is 0 (these can only be module items and have no content id).
item_workflow_state | The workflow state of the item (e.g. active, unpublished) | You could filter to only active to remove unpublished items. 
item_title | The title of the item. | 
item_requirement | The requirement type for the item (e.g. min_score) | You could filter to exclude `null` to only include items with active requirements 
item_requirement_min_score | The minimum score required for the item |  if applicable.
user_id | The ID of the user enrolled in the course. | 
user_name | The name of the user. | 
user_progression_id | The progression ID for the user within the module. | 
user_module_state | The completion state of the module for the user (e.g. completed, started, unlocked, locked) | 
user_module_completed_at | The date and time when the user completed the module. | 
user_met_item_requirement | Indicates whether the user met the item's requirement (true/false) | Evaluates if the user has met the item requirement based on the given conditions.
