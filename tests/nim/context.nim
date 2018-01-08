import
  py2nim_helpers

type
  VMError* = object of Exception
type
  A* = object of RootObj
    a*: int

method enter*(self: var A): void =
  self.a = 2

method exit*(self: var A; exc_type: ref Exception; exc_value: ref Exception;
            traceback: string): void =
  if not exc_value.isNil() and exc_value of VMError:
    echo "ERROR"
  else:
    self.a = - 2
  
var a = A(a: 0)
try:
  with a,
    raise newException(VMError, "")
except :
  echo 0
