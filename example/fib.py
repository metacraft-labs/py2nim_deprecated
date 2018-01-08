def test():
    print(fib(4))


def fib(n):
    if n <= 1:
        return 1
    else:
        return fib(n - 2) + fib(n - 1)

if __name__ == '__main__':
    test()
