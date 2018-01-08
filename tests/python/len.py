class A:

    def __init__(self, elements):
        self.elements = elements

    def __len__(self):
        return len(self.elements)

a = A([2])
print(len(a))
