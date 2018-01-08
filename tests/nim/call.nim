type
  A* = object
proc `()`*(self: A; a: int): void =
  echo a

var a = A()
a(2)
