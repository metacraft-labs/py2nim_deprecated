import
  sequtils

proc a*(z: int): void =
  echo z + z

proc a*(z: string): void =
  echo z & z

proc a*(z: seq[int]): void =
  echo z.concat(z)

a(0)
a("e")
a(@[0])
