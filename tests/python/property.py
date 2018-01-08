class A:

    def __init__(self, a):
        self.a = a

    @property
    def z(self):
        return self.a + 8

a = A(2)
print(a.z)
