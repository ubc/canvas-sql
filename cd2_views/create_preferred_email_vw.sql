CREATE OR REPLACE VIEW canvas.preferred_email_vw as
SELECT
  comm1.user_id,
  comm1.path as email
FROM
  canvas.communication_channels comm1
  JOIN (
    SELECT
      user_id,
      MIN(position) AS min_position
    FROM
      canvas.communication_channels comm2
    WHERE
      path_type = 'email'
      AND workflow_state = 'active'
    GROUP BY
      user_id
    ) AS min_positions
    ON comm1.user_id = min_positions.user_id
    AND comm1.position = min_positions.min_position
