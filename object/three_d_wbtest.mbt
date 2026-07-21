///|
fn assert_3d_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
}

///|
test "vec3 cross product and z alignment establish surface normals" {
  let normal = Vec3::unit_x().cross(Vec3::unit_y())
  assert_3d_close(normal.x, 0.0)
  assert_3d_close(normal.y, 0.0)
  assert_3d_close(normal.z, 1.0)
  let direction = Vec3::new(x=1.0, y=2.0, z=3.0).normalize_or(Vec3::unit_z())
  let aligned = Transform::align_z_to(direction).apply_vec(Vec3::unit_z())
  assert_3d_close(aligned.x, direction.x)
  assert_3d_close(aligned.y, direction.y)
  assert_3d_close(aligned.z, direction.z)
}

///|
test "mesh validates topology and interpolates vertices" {
  let invalid = try
    Mesh3D::new([Vec3::zero()], [MeshFace3D::new([0, 1, 2])])
  catch {
    error => Err(error)
  } noraise {
    mesh => Ok(mesh)
  }
  assert_true(invalid is Err(VertexIndexOutOfBounds(..)))
  let start = Mesh3D::polygon([Vec3::zero(), Vec3::unit_x(), Vec3::unit_y()])
  let target = start.map_vertices(point => point.add(Vec3::unit_z()))
  guard start.lerp(target, 0.5) is Some(midpoint) else {
    fail("matching mesh topology should interpolate")
  }
  guard midpoint.face_vertices(0) is Some(vertices) else {
    fail("interpolated mesh should retain its face")
  }
  for point in vertices {
    assert_3d_close(point.z, 0.5)
  }
}

///|
test "surface samples addressable checkerboard mesh patches" {
  let surface = Surface::new(
    (u, v) => Vec3::new(x=u, y=v, z=u + v),
    u_resolution=2,
    v_resolution=3,
  )
  let object = into_object(surface)
  guard object.node is Group(patches) else {
    fail("surface should lower to a patch family")
  }
  assert_eq(patches.length(), 6)
  guard patches[0].node is Mesh(first, first_style) &&
    patches[1].node is Mesh(second, second_style) else {
    fail("surface patches should be mesh leaves")
  }
  assert_eq(first.face_count(), 1)
  assert_eq(second.face_count(), 1)
  assert_true(first_style.fill != second_style.fill)
}

///|
test "sphere and cube expose three dimensional bounds and face families" {
  let sphere = into_object(
    Sphere::new(radius=2.0, u_resolution=8, v_resolution=4),
  )
  guard sphere.bounds() is Some(sphere_bounds) else {
    fail("sphere should have bounds")
  }
  assert_3d_close(sphere_bounds.min.x, -2.0)
  assert_3d_close(sphere_bounds.max.x, 2.0)
  assert_3d_close(sphere_bounds.min.z, -2.0)
  assert_3d_close(sphere_bounds.max.z, 2.0)
  let cube = into_object(Cube::new(side_length=3.0))
  guard cube.node is Group(faces) else {
    fail("cube should lower to six mesh faces")
  }
  assert_eq(faces.length(), 6)
  assert_true(faces.all(face => face.node is Mesh(_, _)))
  guard cube.bounds() is Some(cube_bounds) else {
    fail("cube should have bounds")
  }
  assert_3d_close(cube_bounds.width(), 3.0)
  assert_3d_close(cube_bounds.height(), 3.0)
  assert_3d_close(cube_bounds.depth(), 3.0)
}

///|
test "three dimensional axes preserve z coordinates in plotted curves" {
  let axes = ThreeDAxes::new(
    x_min=-1.0,
    x_max=1.0,
    y_min=-1.0,
    y_max=1.0,
    z_min=-1.0,
    z_max=1.0,
    x_length=2.0,
    y_length=2.0,
    z_length=2.0,
  )
  let curve = axes.plot_parametric_curve(
    t => Vec3::new(x=t, y=0.0, z=t),
    t_min=-1.0,
    t_max=1.0,
    step=1.0,
  )
  guard curve.path().commands.last() is Some(LineTo(last)) else {
    fail("parametric curve should end with a line command")
  }
  assert_3d_close(last.x, 1.0)
  assert_3d_close(last.z, 1.0)
}
