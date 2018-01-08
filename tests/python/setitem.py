class A:

    def __setitem__(self, e, f):
        print(e + f)

a = A()
a[2] = 8
