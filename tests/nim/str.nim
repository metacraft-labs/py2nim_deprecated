type
  A* = object of RootObj
proc `$`*(self: A): string
proc `$`*(self: A): string =
  return "a"

var a = A()
echo a
