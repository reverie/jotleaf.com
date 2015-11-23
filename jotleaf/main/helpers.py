from main import permissions

def object_to_dict(obj, field_names):
    return dict(
        (name, permissions.get_field_value(obj, name))
        for name in field_names
    )

def simple_read(instance):
    """
    Used for outside functions, to get the same
    data that the API would get.
    """
    model = instance.__class__
    fields = permissions.get_model_default_readable_fields(model)
    return object_to_dict(instance, fields)