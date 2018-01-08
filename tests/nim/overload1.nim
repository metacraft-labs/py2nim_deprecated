proc a*(z: int; b: float): void =
  echo z.float + b

proc a*(z: string; b: string): void =
  echo z & b

a(0, 0.0)
a("e", "")
