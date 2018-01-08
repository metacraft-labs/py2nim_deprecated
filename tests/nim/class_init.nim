
type
  A* = object of RootObj
    a*: int

proc makeA*(): A
proc makeA*(): A =
  result.a = 2

var a = makeA()
