class A:

    def __delitem__(self, e):
        print(0)

a = A()
del a[23]
