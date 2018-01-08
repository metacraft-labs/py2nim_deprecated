class VMError(Exception):
    pass


class A:

    def __init__(self, a):
        self.a = a

    def __enter__(self):
        self.a = 2

    def __exit__(self, exc_type, exc_value, traceback):
        if exc_value and isinstance(exc_value, VMError):
            print('ERROR')
        else:
            self.a = -2

a = A(0)
try:
    with a:
        raise VMError('')
except:
    print(0)
