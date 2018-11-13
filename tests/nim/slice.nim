proc t*(a: seq[int]): seq[int] =
  return a[2 .. ^1]

var a = t(@[1, 2, 3, 4])
echo a
echo a[1 .. ^2]
echo a[0 ..< 2]
