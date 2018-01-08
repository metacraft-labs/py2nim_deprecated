type
  A* = object of RootObj
proc `[]`*(self: A; e: int): int
proc `[]`*(self: A; e: int): int =
  return e

var a = A()
echo a[2]
