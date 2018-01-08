import
  algorithm

type
  A* = object of RootObj
    values*: seq[int]
    z*: int

proc makeA*(values: seq[int]): A
proc makeA*(values: seq[int]): A =
  result.values = values
  result.z = len(result.values)

iterator items*(self: var A): int =
  while true:
    self.z -= 1
    if self.z < 0:
      break
    yield self.values[self.z]

iterator b*(values: seq[int]): int =
  for z in reversed(values):
    yield z

var a = makeA(@ [2, 4])
for z in a:
  echo z
for z in b(@ [2, 4]):
  echo z
