# Coordinate-system conversions and change-of-basis helpers. Scalar-only
# (follows the package convention: modules are independent and never share
# struct field access across files). All multi-value results are written into
# caller-provided double* buffers.
#   - 2D polar <-> cartesian
#   - 3D spherical <-> cartesian  (theta = azimuth in xy-plane [0, 2*pi],
#     phi = inclination from +z [0, pi])
#   - 3D cylindrical <-> cartesian
#   - Change of basis: express/reconstruct a point in an orthonormal frame.

import "scalar.cpy"

# 2D polar (radius, angle in radians) -> cartesian. Writes x into and[0],
# y into and[1].
public def polar_to_cartesian(radius double, theta double, out double*) -> void:
    out[0] = radius * cos(theta)
    out[1] = radius * sin(theta)

# 2D cartesian -> polar. Writes radius into and[0], angle (radians in
# [-pi, pi]) into and[1].
public def cartesian_to_polar(x double, y double, out double*) -> void:
    double r = scalar_sqrt(x * x + y * y)
    out[0] = r
    out[1] = atan2(y, x)

# 3D spherical (radius, azimuth theta, inclination phi) -> cartesian.
public def spherical_to_cartesian(radius double, theta double, phi double, out double*) -> void:
    double sin_phi = sin(phi)
    out[0] = radius * sin_phi * cos(theta)
    out[1] = radius * sin_phi * sin(theta)
    out[2] = radius * cos(phi)

# 3D cartesian -> spherical. Writes r into and[0], theta into and[1],
# phi into and[2].
public def cartesian_to_spherical(x double, y double, z double, out double*) -> void:
    double r = scalar_sqrt(x * x + y * y + z * z)
    out[0] = r
    if r > 0.0:
        out[1] = atan2(y, x)
        double cos_phi = z / r
        if cos_phi > 1.0:
            cos_phi = 1.0
        if cos_phi < -1.0:
            cos_phi = -1.0
        out[2] = acos(cos_phi)
    else:
        out[1] = 0.0
        out[2] = 0.0

# 3D cylindrical (radius rho, azimuth phi, height h) -> cartesian.
public def cylindrical_to_cartesian(rho double, phi double, h double, out double*) -> void:
    out[0] = rho * cos(phi)
    out[1] = rho * sin(phi)
    out[2] = h

# 3D cartesian -> cylindrical. Writes rho into and[0], phi into and[1],
# h into and[2].
public def cartesian_to_cylindrical(x double, y double, z double, out double*) -> void:
    out[0] = scalar_sqrt(x * x + y * y)
    out[1] = atan2(y, x)
    out[2] = z

# Express a point p=(px,py,pz) in the orthonormal frame whose axes are
# u=(ux,uy,uz), v=(vx,vy,vz), n=(nx,ny,nz). Writes the local components into
# out[0..2]. Requires the frame axes to be orthonormal (unit length, mutually
# perpendicular). Inverse of change_basis_inverse.
public def change_basis(px double, py double, pz double,
                        ux double, uy double, uz double,
                        vx double, vy double, vz double,
                        nx double, ny double, nz double, out double*) -> void:
    out[0] = px * ux + py * uy + pz * uz
    out[1] = px * vx + py * vy + pz * vz
    out[2] = px * nx + py * ny + pz * nz

# Reconstruct a world point from local components (lx, ly, lz) using the same
# orthonormal frame. Writes the world point into out[0..2].
public def change_basis_inverse(lx double, ly double, lz double,
                                ux double, uy double, uz double,
                                vx double, vy double, vz double,
                                nx double, ny double, nz double, out double*) -> void:
    out[0] = lx * ux + ly * vx + lz * nx
    out[1] = lx * uy + ly * vy + lz * ny
    out[2] = lx * uz + ly * vz + lz * nz
