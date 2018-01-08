
with open('a', 'r') as f:
    source = f.read()

print(source)

with open('b', 'w') as f:
    f.write(source)

# lines = source.split('\n')
# for z, line in enumerate(lines):
#     print(line)

# a = 0
# while a == 0:
#     a = 2
