type
  A* = object of RootObj
method `[]`*(self: A; e: int): int =
  return e

var a = A()
echo a[2]
