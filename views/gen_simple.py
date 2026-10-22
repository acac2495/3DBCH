import numpy as np

N = 15

# 2x2 block in the XY slice z=Z0, rows x in {X0, X0+1}, cols y in {Y0, Y0+1}
Z0, X0, Y0 = 5, 3, 7
WRAP = False          # True -> quasi-cyclic wrap: x in {14,0}, y in {14,0}

xs = [14, 0] if WRAP else [X0, X0 + 1]
ys = [14, 0] if WRAP else [Y0, Y0 + 1]

cube = np.zeros((N, N, N), dtype=np.uint8)
for x in xs:
    for y in ys:
        cube[x, y, Z0] = 1

# bit index = (x*N + y)*N + z, bit 0 = cube[0,0,0]
val = 0
for i, b in enumerate(cube.reshape(-1)):
    val |= int(b) << i

with open("cube_in.hex", "w") as f:
    f.write(format(val, "x") + "\n")

print(f"wrote cube_in.hex with {int(cube.sum())} errors, XY slice z={Z0}")