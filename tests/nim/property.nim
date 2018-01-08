type
  A* = object
    a*: int

proc z*(self: A): int =
  return self.a + 8

var a = A(a: 2)
echo a.z
