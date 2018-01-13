class A:

    def __init__(self, values):
        self.values = values
        self.z = len(self.values)

    def __iter__(self):
        return self

    def __next__(self):
        self.z -= 1
        if self.z < 0:
            raise StopIteration()
        return self.values[self.z]


# def b(values):
#     for z in reversed(values):
#         yield z

a = A([2, 4])
for z in a:
    print(z)

# for z in b([2, 4]):
#     print(z)
