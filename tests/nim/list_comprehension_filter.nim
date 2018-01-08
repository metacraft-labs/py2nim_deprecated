import
  sequtils

var a = @[2, 4]
echo a.filterIt(it > 2).mapIt(it + 2)
