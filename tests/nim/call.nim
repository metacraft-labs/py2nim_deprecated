type
  A* = object of RootObj
proc `()`*(self: A; a: int): void
proc `()`*(self: A; a: int): void =
  echo a

var a = A()
a(2)
