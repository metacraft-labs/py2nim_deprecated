class A:

    def __getitem__(self, e):
        return e

a = A()
print(a[2])
