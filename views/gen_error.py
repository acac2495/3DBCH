import numpy as np

N = 15

cube = np.zeros((N, N, N), dtype=np.uint8)

# errors from the notebook (x, y, z)
pts = [(1,8),(1,12),(2,8),(2,10),(2,12),(4,8),(4,12),(5,8),(5,12)]  # (x, y)
for xo in (0, 7):          # x offset: 0 and 7 -> x in 1..5 and 8..12
    for z in (5, 10):
        for x, y in pts:
            cube[x + xo, y, z] = 1

# bit index = (x*N + y)*N + z, bit 0 = cube[0,0,0]
val = 0
for i, b in enumerate(cube.reshape(-1)):
    val |= int(b) << i

with open("cube_in.hex", "w") as f:
    f.write(format(val, "x") + "\n")

print(f"wrote cube_in.hex with {int(cube.sum())} errors")