a = [2, 4]

# we can compile generators to iterators
# but it seems like something that one should manually decide
print(element + 2 for element in a if element > 2)
