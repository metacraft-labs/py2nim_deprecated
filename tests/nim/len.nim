
type
  A* = object of RootObj
    elements*: seq[int]

proc len*(self: A): int
proc len*(self: A): int =
  return len(self.elements)

var a = A(elements: @ [2])
echo len(a)
