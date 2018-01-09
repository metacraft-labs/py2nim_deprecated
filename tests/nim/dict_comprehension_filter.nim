import
  tables, py2nim_helpers

var
  a = {2: 4}.toTable()
  b = @[2, 4]
echo a.filterTable(
  k == 0).mapTable(k + 2: v - 2)
echo b.filterTable(
  it > 2).mapTable(it: 2)
