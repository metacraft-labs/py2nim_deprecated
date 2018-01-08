proc t*(a: (int, string)): void
proc t*(a: (int, string)): void =
  echo a

var a = (2, "4")
t(a)
