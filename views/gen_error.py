import numpy as np

N = 15

test_cube = np.zeros((N, N, N), dtype=np.uint8)

# Burst A: 2 x 2 x 4 block (each XY slice sees a 2x2 square)
test_cube[13:15, 0:2, 0:4] = 1

# Burst B: 2 x 4 x 2 block (XY slices see 2x4, XZ slices see a 2x2 square)
test_cube[6:8, 2:6, 7:9] = 1

# Four copies of the spread-out pattern
pts = [(1,8),(1,12),(2,8),(2,10),(2,12),(4,8),(4,12),(5,8),(5,12)]  # (x, y)
for xo in (0, 7):
    for z in (5, 10):
        for x, y in pts:
            test_cube[x + xo, y, z] = 1

# bit index = (x*N + y)*N + z, bit 0 = cube[0,0,0]
val = 0
for i, b in enumerate(test_cube.reshape(-1)):
    val |= int(b) << i

with open("cube_in.hex", "w") as f:
    f.write(format(val, "x") + "\n")

print(f"wrote cube_in.hex with {int(test_cube.sum())} errors")