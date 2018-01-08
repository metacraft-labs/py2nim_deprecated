def plus(a, b):
    return a + b


def fsum(a, b, c):
    return plus(plus(a, b), c)


print("TOP LEVEL SUM " + str(fsum(10, 20, 30)))
