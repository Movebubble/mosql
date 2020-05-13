
/* Functions */

CREATE OR REPLACE FUNCTION json_array_to_text_array(
  p_input json
) RETURNS TEXT[] AS $BODY$

DECLARE v_output text[];

BEGIN

  SELECT array_agg(ary)::text[]
  INTO v_output
  FROM json_array_elements_text(p_input) AS ary;

  RETURN v_output;

END;

$BODY$
LANGUAGE plpgsql VOLATILE;


/* Materialized views */ 


DROP MATERIALIZED VIEW IF EXISTS units_packages;
CREATE MATERIALIZED VIEW units_packages AS 
 WITH units_packages AS (
         SELECT units.id,
            json_array_elements(units._extra_props -> 'packages'::text) AS p
           FROM units
        )
 SELECT units_packages.id,
    units_packages.p ->> 'packageId'::text AS package_id,
    (units_packages.p ->> 'createdAt'::text)::timestamp without time zone AS created_at
   FROM units_packages;
REFRESH MATERIALIZED VIEW units_packages;


DROP MATERIALIZED VIEW IF EXISTS property_sources;
CREATE MATERIALIZED VIEW property_sources AS
 WITH p_sources AS (
         SELECT properties.id,
            json_array_elements(properties._extra_props -> 'sources'::text) AS s
           FROM properties
        )
 SELECT p_sources.id,
    p_sources.s ->> 'sourceId'::text AS source_id,
    p_sources.s ->> 'sourceType'::text AS source_type,
    p_sources.s ->> 'sourceSubType'::text AS source_sub_type
   FROM p_sources;
REFRESH MATERIALIZED VIEW property_sources;


DROP MATERIALIZED VIEW IF EXISTS property_features;
CREATE MATERIALIZED VIEW property_features AS
 WITH property_features AS (
         SELECT properties.id,
            json_array_elements(properties._extra_props -> 'features'::text) AS features
           FROM properties
        )
 SELECT property_features.id,
    property_features.features ->> 'featureType'::text AS feature
   FROM property_features;
REFRESH MATERIALIZED VIEW property_features;


DROP MATERIALIZED VIEW IF EXISTS enquiries_interactions;
CREATE MATERIALIZED VIEW enquiries_interactions AS
 WITH enquiries_interactions AS (
         SELECT enquiries.id,
            json_array_elements(enquiries._extra_props -> 'interactions'::text) AS ei
           FROM enquiries
        )
 SELECT enquiries_interactions.id,
    enquiries_interactions.ei ->> 'type'::text AS type,
    (enquiries_interactions.ei ->> 'createdAt'::text)::timestamp without time zone AS created_at,
    enquiries_interactions.ei -> 'createdBy' ->> 'entityId'::text AS created_by,
    enquiries_interactions.ei -> 'details' ->> 'phoneNumber'::text AS phone_number,
    enquiries_interactions.ei -> 'details' ->> 'email'::text AS email,
    enquiries_interactions.ei -> 'details' ->> 'chatToken'::text AS chat_token
   FROM enquiries_interactions;
REFRESH MATERIALIZED VIEW enquiries_interactions;


DROP MATERIALIZED VIEW IF EXISTS users_app_logins;
CREATE MATERIALIZED VIEW users_app_logins AS
 WITH users_app_logins AS (
         SELECT users.id,
            json_array_elements(users._extra_props -> 'appCredentials'::text) AS ac
           FROM users
        )
 SELECT users_app_logins.id,
    users_app_logins.ac ->> 'organizationId'::text AS organization_id,
    users_app_logins.ac ->> 'unitId'::text AS unit_id,

    json_array_to_text_array(users_app_logins.ac -> 'appKeys'::text) AS app_keys,
    json_array_to_text_array(users_app_logins.ac -> 'userRoleIds'::text) AS user_role_ids,
    ( SELECT latest_status.status
           FROM ( SELECT json_array_elements(app_credentials.ac -> 'statuses'::text) ->> 'status'::text AS status,
                    (json_array_elements(app_credentials.ac -> 'statuses'::text) ->> 'createdAt'::text)::timestamp without time zone AS status_created_at
                   FROM users_app_logins app_credentials
                  ORDER BY ((json_array_elements(app_credentials.ac -> 'statuses'::text) ->> 'createdAt'::text)::timestamp without time zone) DESC
                 LIMIT 1) latest_status) AS status
   FROM users_app_logins;
REFRESH MATERIALIZED VIEW users_app_logins;

DROP MATERIALIZED VIEW IF EXISTS chat_messages_seen;
CREATE MATERIALIZED VIEW chat_messages_seen AS
 WITH chat_messages_seen AS (
         SELECT chat_messages.id,
            json_array_elements(chat_messages._extra_props -> 'seenBy'::text) AS seen_by
           FROM chat_messages
        )
 SELECT chat_messages_seen.id,
    chat_messages_seen.seen_by ->> 'userId'::text AS user_id,
    chat_messages_seen.seen_by ->> 'chatRole'::text AS user_chat_role,
    (chat_messages_seen.seen_by ->> 'seenAt'::text)::timestamp without time zone AS seen_at
   FROM chat_messages_seen;
REFRESH MATERIALIZED VIEW chat_messages_seen;


DROP MATERIALIZED VIEW IF EXISTS chat_messages_transmitted;
CREATE MATERIALIZED VIEW chat_messages_transmitted AS
 WITH chat_messages_transmitted AS (
         SELECT chat_messages.id,
            json_array_elements(chat_messages._extra_props -> 'transmittedTo'::text) AS transmited_to
           FROM chat_messages
        )
 SELECT chat_messages_transmitted.id,
    chat_messages_transmitted.transmited_to ->> 'userId'::text AS user_id,
    chat_messages_transmitted.transmited_to ->> 'chatRole'::text AS user_chat_role
   FROM chat_messages_transmitted;
REFRESH MATERIALIZED VIEW chat_messages_transmitted;


DROP MATERIALIZED VIEW IF EXISTS user_app_devices;
CREATE MATERIALIZED VIEW user_app_devices AS
 WITH user_app_devices AS (
         SELECT user_device_app_details.id,
            user_device_app_details.user_id,
            json_array_elements(user_device_app_details._extra_props -> 'appVersionDeviceDetails'::text) ->> 'appKey'::text AS appkey,
            json_array_elements(user_device_app_details._extra_props -> 'appVersionDeviceDetails'::text) -> 'devices'::text AS devices
           FROM user_device_app_details
        )
 SELECT devices_per_app.id,
    devices_per_app.user_id as user_id,
    devices_per_app.appkey as app_key,
    devices_per_app.device ->> 'make'::text AS make,
    devices_per_app.device ->> 'model'::text AS model,
    devices_per_app.device ->> 'os'::text AS os,
    devices_per_app.device ->> 'osVersion'::text AS os_version,
    devices_per_app.device ->> 'type'::text AS device_type,
    devices_per_app.device ->> 'platformType'::text AS platform_type,
    devices_per_app.device ->> 'deviceId'::text AS device_id,
    devices_per_app.device ->> 'registrationToken'::text AS registration_token,
    (devices_per_app.device ->> 'date'::text)::timestamp without time zone AS date,
    devices_per_app.device ->> 'active'::text AS active
   FROM ( SELECT dv.id,
            dv.user_id,
            dv.appkey,
            json_array_elements(dv.devices) AS device
           FROM user_app_devices dv) devices_per_app;
REFRESH MATERIALIZED VIEW user_app_devices;


DROP MATERIALIZED VIEW IF EXISTS renter_search_filters;
CREATE MATERIALIZED VIEW renter_search_filters AS
 WITH renter_search_filters AS (
         SELECT renter_searches.id,
            renter_searches.user_id,
            json_array_elements(renter_searches._extra_props -> 'entityFilters'::text) AS entity_filter
           FROM renter_searches
        )
 SELECT renter_search_filters.id,
    renter_search_filters.user_id,
    renter_search_filters.entity_filter ->> 'type'::text AS filter_type,
    renter_search_filters.entity_filter ->> 'key'::text AS filter_value
   FROM renter_search_filters;
REFRESH MATERIALIZED VIEW renter_search_filters;


DROP MATERIALIZED VIEW IF EXISTS video_groups_statuses;
CREATE MATERIALIZED VIEW video_groups_statuses AS
 WITH vg AS (
         SELECT video_groups.id,
	 	 video_groups.details_property_id,
	 	 video_groups.details_community_id,
            json_array_elements(video_groups._extra_props -> 'statuses'::text) AS s
           FROM video_groups
        )
 SELECT vg.id, vg.details_property_id, vg.details_community_id,
    vg.s ->> 'statusType'::text AS status_type,
    (vg.s ->> 'createdAt'::text)::timestamp without time zone AS created_at,
    (vg.s -> 'createdBy' ->> 'entityId')::text AS created_by_entity_id,
    (vg.s -> 'createdBy' ->> 'entityType')::text AS created_by_entity_type
   FROM vg;
REFRESH MATERIALIZED VIEW video_groups_statuses;


/* Refresh views */
REFRESH MATERIALIZED VIEW units_packages;
REFRESH MATERIALIZED VIEW users_app_logins;
REFRESH MATERIALIZED VIEW renter_search_filters;
REFRESH MATERIALIZED VIEW user_app_devices;
REFRESH MATERIALIZED VIEW chat_messages_seen;
REFRESH MATERIALIZED VIEW chat_messages_transmitted;
REFRESH MATERIALIZED VIEW enquiries_interactions;
REFRESH MATERIALIZED VIEW property_sources;
REFRESH MATERIALIZED VIEW property_features;
REFRESH MATERIALIZED VIEW video_groups_statuses;



/* Indexes */

DROP INDEX IF EXISTS chat_messages_seen_id_user_id_user_chat_role_idx;
CREATE INDEX chat_messages_seen_id_user_id_user_chat_role_idx ON chat_messages_seen (id, user_id, user_chat_role);

DROP INDEX IF EXISTS chat_messages_transmitted_id_user_id_user_chat_role_idx;
CREATE INDEX chat_messages_transmitted_id_user_id_user_chat_role_idx ON chat_messages_transmitted (id, user_id, user_chat_role);

DROP INDEX IF EXISTS renter_search_filters_id_user_id_filter_type_idx;
CREATE INDEX renter_search_filters_id_user_id_filter_type_idx ON renter_search_filters (id, user_id, filter_type);

DROP INDEX IF EXISTS user_app_devices_user_id_device_id_app_key_idx;
CREATE INDEX user_app_devices_user_id_device_id_app_key_idx ON user_app_devices (user_id, device_id, app_key);

DROP INDEX IF EXISTS enquiries_interactions_id_idx;
CREATE INDEX enquiries_interactions_id_idx ON enquiries_interactions (id);

DROP INDEX IF EXISTS enquiries_interactions_id_type_created_at_idx;
CREATE INDEX enquiries_interactions_id_type_created_at_idx ON enquiries_interactions (id, type, created_at);

DROP INDEX IF EXISTS chat_messages_chat_id_idx;
CREATE INDEX chat_messages_chat_id_idx ON chat_messages (chat_id);

DROP INDEX IF EXISTS agents_details_user_id_idx;
CREATE INDEX agents_details_user_id_idx ON agents_details (user_id);

DROP INDEX IF EXISTS renters_details_user_id_idx;
CREATE INDEX renters_details_user_id_idx ON renters_details (user_id);

DROP INDEX IF EXISTS users_app_logins_id_idx;
CREATE INDEX users_app_logins_id_idx ON users_app_logins (id);

DROP INDEX IF EXISTS property_sources_id_idx;
CREATE INDEX property_sources_id_idx ON property_sources (id);

DROP INDEX IF EXISTS units_packages_id_idx;
CREATE INDEX units_packages_id_idx ON units_packages (id);

DROP INDEX IF EXISTS acl_operation_and_subject_type_and_subject_id_idx;
CREATE INDEX acl_operation_and_subject_type_and_subject_id_idx ON acl (operation,subject_type,subject_id);

DROP INDEX IF EXISTS acl_operation_and_object_type_and_object_id_idx;
CREATE INDEX acl_operation_and_object_type_and_object_id_idx ON acl (operation,object_type,object_id);

DROP INDEX IF EXISTS videos_video_group_id_idx;
CREATE INDEX videos_video_group_id_idx ON videos (video_group_id);

DROP INDEX IF EXISTS videos_clip_config_key_idx;
CREATE INDEX videos_clip_config_key_idx ON videos (clip_config_key);

DROP INDEX IF EXISTS video_groups_details_property_id_idx;
CREATE INDEX video_groups_details_property_id_idx ON video_groups (details_property_id);

DROP INDEX IF EXISTS video_groups_details_community_id_idx;
CREATE INDEX video_groups_details_community_id_idx ON video_groups (details_community_id);

DROP INDEX IF EXISTS clip_configurations_key_idx;
CREATE INDEX clip_configurations_key_idx ON clip_configurations (key);

DROP INDEX IF EXISTS clip_configurations_type_idx;
CREATE INDEX clip_configurations_type_idx ON clip_configurations (type);

DROP INDEX IF EXISTS clip_configurations_key_type_idx;
CREATE INDEX clip_configurations_key_type_idx ON clip_configurations (key,type);

DROP INDEX IF EXISTS video_processing_runs_type_idx;
CREATE INDEX video_processing_runs_type_idx ON video_processing_runs (type);

DROP INDEX IF EXISTS video_processing_runs_video_id_idx;
CREATE INDEX video_processing_runs_video_id_idx ON video_processing_runs (video_id);

DROP INDEX IF EXISTS video_processing_runs_video_group_id_idx;
CREATE INDEX video_processing_runs_video_group_id_idx ON video_processing_runs (video_group_id);

DROP INDEX IF EXISTS renter_traced_searches_saved_search_id_idx;
CREATE INDEX renter_traced_searches_saved_search_id_idx ON renter_traced_searches (saved_search_id);

DROP INDEX IF EXISTS analytics_events_app_key_and_type_and_user_id_idx;
CREATE INDEX analytics_events_app_key_and_type_and_user_id_idx ON analytics_events (app_key, type, user_id);

DROP INDEX IF EXISTS analytics_events_app_key_and_type_and_related_unit_package_id_idx;
CREATE INDEX analytics_events_app_key_and_type_and_related_unit_package_id_idx ON analytics_events (app_key, type, type_details_related_unit_package_id);

DROP INDEX IF EXISTS report_jobs_created_at_and_status_and_report_name_idx;
CREATE INDEX report_jobs_created_at_and_status_and_report_name_idx ON report_jobs (created_at, status, report_name);