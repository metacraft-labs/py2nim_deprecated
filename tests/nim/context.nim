import
  py2nim_helpers

type
  VMError* = object of Exception
type
  A* = object
    a*: int

proc enter*(self: var A): void =
  self.a = 2

proc exit*(self: var A; excType: ref Exception; excValue: ref Exception; traceback: string): void =
  if notexcValue.isNil() and excValue of VMError:
    echo "ERROR"
  else:
    self.a = -2
  
var a = A(a: 0)
try:
  with a,
    raise newException(VMError, "")
except :
  echo 0
