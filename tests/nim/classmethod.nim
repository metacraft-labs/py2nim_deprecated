type
  A* = object
proc z*(cls: typedesc; a: int): int =
  return a

echo A.z(2)
