type
  MyError* = object of Exception
try:
  raise newException(MyError, "z")
except MyError:
  echo getCurrentExceptionMsg()
try:
  raise newException(Exception, "z")
except Exception:
  echo getCurrentExceptionMsg()

