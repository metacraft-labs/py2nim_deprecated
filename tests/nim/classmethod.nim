type
  A* = object of RootObj
proc z*(cls: typedesc; a: int): int
proc z*(cls: typedesc; a: int): int =
  return a

echo A.z(2)
