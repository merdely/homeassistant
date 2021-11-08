entity_id = data.get('entity_id')
if not entity_id:
    logger.error('No entity_id provided')

state = data.get('state')
if not state:
    logger.error('No state provided')

attr_change = data.get('attributes')

entity = hass.states.get(entity_id)
attributes = entity.attributes.copy()

try:
    for key in attr_change:
        attributes[key] = attr_change[key]
except:
    pass

hass.states.set(entity_id, state, attributes)
