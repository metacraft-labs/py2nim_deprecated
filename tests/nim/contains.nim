type
  A* = object
proc contains*(self: A; e: int): bool =
  return false

var a = A()
echo 0 in a
