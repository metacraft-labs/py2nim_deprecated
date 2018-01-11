import
  py2nim_helpers

type
  Z* = object
    field*: int

proc b*(z: auto): auto =
  return z + 2

proc b*(z: HasField(field)): int =
  return z.field

proc b*[T](z: seq[T]): int =
  return z

echo b(Z(field: 0))
echo b(@[0])
echo b(0)
