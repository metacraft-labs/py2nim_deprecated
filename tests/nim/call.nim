type
  A* = object of RootObj
method `()`*(self: A; a: int): void =
  echo a

var a = A()
a(2)
