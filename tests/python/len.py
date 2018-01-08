class A:

    def __init__(self, elements):
        self.elements = elements

    def __len__(self):
        return len(self.elements)


class B(A):

    def __len__(self):
        return 2

a = A([2])
print(len(a))
b = B([])
print(len(b))
