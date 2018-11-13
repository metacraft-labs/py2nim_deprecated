import
  tables, py2nim_helpers, sequtils

var
  a = {2: 4}.newTable()
  b = @[2, 4]
echo a.mapTable((k + 2, v - 2))
echo b.mapTable((it, 2))
