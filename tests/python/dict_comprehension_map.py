a = {2: 4}
b = [2, 4]

print({k + 2: v - 2 for k, v in a.items()})
print({element: 2 for element in b})
