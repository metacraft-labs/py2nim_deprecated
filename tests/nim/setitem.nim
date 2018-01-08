
type
  A* = object of RootObj
proc `[]=`*(self: A; e: int; f: int): void
proc `[]=`*(self: A; e: int; f: int): void =
  echo e + f

var a = A()
a[2] = 8
