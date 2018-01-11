def b(z):
    if hasattr(z, 'field'):
        return z.field
    elif isinstance(z, list):
        return z
    else:
        return z + 2


class Z:

    def __init__(self, field):
        self.field = field

print(b(Z(0)))
print(b([0]))
print(b(0))
