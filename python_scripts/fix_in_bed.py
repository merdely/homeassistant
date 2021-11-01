entity_id = data.get('entity_id')
if not entity_id:
    logger.error('No entity_id provided')
entity = hass.states.get(entity_id)
#logger.error(entity.attributes)
state = data.get('state')
if not state:
    logger.error('No state provided')
#hass.states.set(entity_id, state)
#hass.states.set(entity_id: entity_id, new_state: state, attributes:{'device_class': 'occupancy'})
hass.states.set(entity_id, state, {'friendly_name': entity.attributes['friendly_name'], 'icon': entity.attributes['icon'], 'device_class': entity.attributes['device_class']})
