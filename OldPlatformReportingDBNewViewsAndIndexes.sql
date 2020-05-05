DROP INDEX IF EXISTS events_occurred_at_and_type_and_entity_id_idx;
CREATE INDEX events_occurred_at_and_type_and_entity_id_idx ON events (occurred_at, event_type, entity_id);