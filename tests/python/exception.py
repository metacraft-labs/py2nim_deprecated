a = [2]
try:
    print(a[1])
    # a[1] = 0
except IndexError as e:
    print(e)


class MyError(Exception):
    pass
