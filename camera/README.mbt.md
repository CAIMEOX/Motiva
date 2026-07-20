# `camera`

`camera` is Motiva's renderer-independent camera package. A `Camera` is a pure
value containing the frame and pixel geometry, view orientation, projection,
zoom, focal distance, background, light source, and shading policy. The active
camera belongs to `Scene`; renderers consume the camera captured in each frame
snapshot instead of maintaining a second mutable copy.

The package implements the camera semantics used by Manim's Cairo renderer:

- `phi`, `theta`, and `gamma` Euler orientation in Manim's rotation order;
- orthographic, perspective, and exponential perspective projection;
- world-to-camera, projection, unprojection, frame-to-pixel, and inverse maps;
- camera-space depth, projected bounds, and frame visibility tests;
- world, fixed-orientation, and fixed-in-frame point transformation;
- Manim-compatible cubic light response for vector-surface shading;
- absolute camera targets, relative camera orbits, and validated interpolation.

```mbt nocheck
let camera = @camera.Camera::new(
  pixel_width=1280,
  pixel_height=720,
  frame_width=14.2222222222,
  projection=@camera.Perspective,
  phi=70.0 * @math.PI / 180.0,
  theta=-135.0 * @math.PI / 180.0,
)

let scene = @scene.Scene::new(camera~)
scene.move_camera(theta=-45.0 * @math.PI / 180.0, run_time=2.0)
```

`Scene::add_fixed_orientation` applies one shared center function to the whole
object family, matching Manim's label behavior. `Scene::add_fixed_in_frame`
bypasses view rotation and projection entirely. Both are independent from the
foreground draw layer.

Depth is exposed by `Camera::depth_at`, but ordinary 2D objects keep their
stable `z_index` order. As in Manim, depth sorting and automatic shading belong
only to objects that explicitly opt into 3D shading; that object-family marker
will arrive with the mesh/surface layer rather than being guessed by Camera.

`Scene::orbit_camera` represents a finite orbit in the normal animation
timeline. Indefinite ambient rotation is intentionally left to the future
updater system rather than introducing hidden work inside `Camera`.
