
type
  A* = object of RootObj
method `[]=`*(self: A; e: int; f: int): void =
  echo e + f

var a = A()
a[2] = 8
