type
  MyError* = object of Exception
var a = @[2]
try:
  echo a[1]
except IndexError:
  echo getCurrentExceptionMsg()
