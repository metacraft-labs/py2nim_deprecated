type
  A* = object
proc `[]`*(self: A; e: int): int =
  return e

var a = A()
echo a[2]
