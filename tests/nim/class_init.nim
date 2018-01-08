
type
  A* = object
    a*: int

proc makeA*(): A =
  result.a = 2

var a = makeA()
