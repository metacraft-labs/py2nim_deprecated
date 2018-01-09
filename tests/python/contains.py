class A:

    def __contains__(self, e):
        return False

a = A()
print(0 in a)
