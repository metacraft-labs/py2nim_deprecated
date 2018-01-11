proc a*(z: auto): auto =
  return @[z]

echo a(0)
echo a("e")
echo a(@[0])
