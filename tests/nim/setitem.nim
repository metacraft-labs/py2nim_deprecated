
type
  A* = object
proc `[]=`*(self: A; e: int; f: int): void =
  echo e + f

var a = A()
a[2] = 8
