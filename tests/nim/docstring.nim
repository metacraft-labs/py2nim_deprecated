type
  Shape* = object
  ##     A class for shape
proc makeShape*(): Shape =
  ##         You won't believe the next five lines
  echo 0

var shape = makeShape()
