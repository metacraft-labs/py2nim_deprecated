type
  A* = object
proc `$`*(self: A): string =
  return "a"

var a = A()
echo a
