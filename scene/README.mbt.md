# `scene`

`scene` owns object identity, animation state, tracked scalar values, and the
continuous-update interpreter. Geometry in `object` remains a pure value;
callbacks and updater lifecycle never become fields of `Object`.

## Continuous updates

An `Updater` is a pure state transition registered in a `Scene`. It targets
exactly one object, `ValueTracker`, or camera and returns that target's next
value. `UpdateContext` is read-only and contains the current absolute time,
`dt`, tracked values, materialized world-space objects, and camera.

Each frame is interpreted in this order:

1. sample and apply active animations;
2. evaluate all value updaters;
3. evaluate all object updaters against the resulting values;
4. evaluate camera updaters against the resulting values and objects;
5. validate every result, then commit one `FramePatch`.

Callbacks in one phase read one immutable phase snapshot, so unrelated targets
do not change meaning when registration order changes. Multiple callbacks on
the same target are deliberately chained in registration order; each receives
the previous callback's result as its first argument. If any callback or
validation fails, none of that update tick is committed.

```mbt nocheck
let phase = scene.value_tracker(0.0)
let dot = scene.always_redraw(context => {
  @object.Dot::new(
    point=@object.Vec3::new(x=context.value(phase), y=0.0),
  )
})

let clock = scene.add_updater(
  @scene.Updater::value(phase, (value, context) => value + context.dt()),
)
scene.play([phase.animate_to(4.0, run_time=2.0)])
ignore(scene.remove_updater(clock))
```

Ordinary `Updater::object` transitions preserve the existing object-family
topology and therefore preserve every `ObjectId`. `Updater::redraw` and
`Scene::always_redraw` use rebuild semantics: the root ID is stable, active
children are reused by position, and temporarily unused child IDs are retained
for later reuse. This supports factories whose family size changes without
unbounded per-frame identity allocation.

Animations suspend updaters on their object family, tracker, or camera by
default, then resume and synchronize them with `dt = 0` at finish. Use
`Animation::with_updater_suspension(false)` when the updater is intentionally
part of the animation. `Scene::suspend_updating` and the corresponding value
and camera methods expose the same nest-safe suspension counters directly.
