type
  A* = object
proc del*(self: A; e: int): void =
  echo 0

var a = A()
del(a, 23)
