///|
priv struct AnimationLifecycle {
  introducer : Bool
  remover : Bool
  has_frame_effect : Bool
}

///|
priv struct ActiveChild {
  animation : ActiveAnimation
  start_time : Double
  end_time : Double
}

///|
priv struct ReplacementFinish {
  source : ObjectId
  target : ObjectId
}

///|
priv enum ActiveAnimationKind {
  ActiveWait
  ActiveCamera(start~ : @camera.Camera, target~ : @camera.Camera)
  ActiveValue(ValueTracker, start~ : Double, target~ : Double)
  ActiveTransform(ObjectId, start~ : @object.Object, target~ : @object.Object)
  ActiveScale(ObjectId, start~ : @object.Object, spec~ : ScaleSpec)
  ActiveRotate(ObjectId, start~ : @object.Object, spec~ : RotationSpec)
  ActiveReveal(ObjectId, source~ : @object.Object, family_size~ : Int)
  ActiveDrawBorderThenFill(
    ObjectId,
    source~ : @object.Object,
    outline~ : @object.Object,
    family_size~ : Int
  )
  ActiveGroup(
    Array[ActiveChild],
    natural_run_time~ : Double,
    replacement~ : ReplacementFinish?
  )
}

///|
priv struct ActiveAnimation {
  kind : ActiveAnimationKind
  timing : Timing
  run_time : Double
  lifecycle : AnimationLifecycle
  suspend_updaters : Bool
}

///|
fn AnimationLifecycle::new(
  introducer~ : Bool,
  remover~ : Bool,
  has_frame_effect~ : Bool,
) -> AnimationLifecycle {
  { introducer, remover, has_frame_effect }
}

///|
fn AnimationLifecycle::passive() -> AnimationLifecycle {
  AnimationLifecycle::new(
    introducer=false,
    remover=false,
    has_frame_effect=false,
  )
}

///|
fn ActiveAnimation::compile(
  scene : Scene,
  animation : Animation,
) -> ActiveAnimation raise SceneError {
  let active = match animation.kind {
    Wait => ActiveAnimation::wait(animation.timing)
    MoveCamera(motion) => {
      let start = scene.camera()
      let target = motion.resolve(start)
      validate_camera(target)
      ActiveAnimation::camera(start~, target~, timing=animation.timing)
    }
    Create(id) =>
      ActiveAnimation::reveal(
        id,
        source=scene.require_materialized_object(id),
        timing=animation.timing,
      )
    DrawBorderThenFill(id) =>
      ActiveAnimation::draw_border_then_fill(
        id,
        source=scene.require_materialized_object(id),
        timing=animation.timing,
      )
    Write(id, lag_ratio) => {
      let source = scene.require_materialized_object(id)
      let family_size = create_family_size(source)
      let resolved_lag_ratio = match lag_ratio {
        Some(value) => value
        None => write_default_lag_ratio(family_size)
      }
      ActiveAnimation::draw_border_then_fill(
        id,
        source~,
        timing=animation.timing.with_lag_ratio(resolved_lag_ratio),
        natural_run_time=write_default_run_time(family_size),
      )
    }
    Scale(id, spec) =>
      ActiveAnimation::scale(
        id,
        start=scene.require_materialized_object(id),
        spec~,
        timing=animation.timing,
      )
    Rotate(id, spec) =>
      ActiveAnimation::rotate(
        id,
        start=scene.require_materialized_object(id),
        spec~,
        timing=animation.timing,
      )
    FadeIn(id, spec) =>
      ActiveAnimation::fade_in(
        id,
        source=scene.require_materialized_object(id),
        spec~,
        timing=animation.timing,
      )
    FadeOut(id, spec) =>
      ActiveAnimation::fade_out(
        id,
        source=scene.require_materialized_object(id),
        spec~,
        timing=animation.timing,
      )
    SetValue(tracker, value) =>
      ActiveAnimation::value(
        tracker,
        start=scene.value(tracker),
        target=value,
        timing=animation.timing,
      )
    IncrementValue(tracker, delta) => {
      let start = scene.value(tracker)
      ActiveAnimation::value(
        tracker,
        start~,
        target=start + delta,
        timing=animation.timing,
      )
    }
    Transform(id, target) => {
      let start = scene.require_materialized_object(id)
      scene.validate_replacement_topology(id, target)
      ActiveAnimation::transform(id, start~, target~, timing=animation.timing)
    }
    ApplyOps(id, ops) => {
      let start = scene.require_materialized_object(id)
      let target = ops.fold(init=start, (object, op) => op.apply(object))
      scene.validate_replacement_topology(id, target)
      ActiveAnimation::transform(id, start~, target~, timing=animation.timing)
    }
    Group(group) =>
      ActiveAnimation::group(scene, group.animations, timing=animation.timing)
    Replacement(group, source~, target~) => {
      ignore(scene.require_object(source))
      ignore(scene.require_object(target))
      ActiveAnimation::group(scene, group.animations, timing=animation.timing, replacement={
        source,
        target,
      })
    }
  }
  { ..active, suspend_updaters: animation.suspend_updaters }
}

///|
fn ActiveAnimation::camera(
  start~ : @camera.Camera,
  target~ : @camera.Camera,
  timing~ : Timing,
) -> ActiveAnimation {
  {
    kind: ActiveCamera(start~, target~),
    timing,
    run_time: timing.resolve_run_time(1.0),
    lifecycle: AnimationLifecycle::new(
      introducer=false,
      remover=false,
      has_frame_effect=true,
    ),
    suspend_updaters: true,
  }
}

///|
fn ActiveAnimation::value(
  tracker : ValueTracker,
  start~ : Double,
  target~ : Double,
  timing~ : Timing,
) -> ActiveAnimation {
  {
    kind: ActiveValue(tracker, start~, target~),
    timing,
    run_time: timing.resolve_run_time(1.0),
    lifecycle: AnimationLifecycle::new(
      introducer=false,
      remover=false,
      has_frame_effect=true,
    ),
    suspend_updaters: true,
  }
}

///|
fn ActiveAnimation::wait(timing : Timing) -> ActiveAnimation {
  {
    kind: ActiveWait,
    timing,
    run_time: timing.resolve_run_time(1.0),
    lifecycle: AnimationLifecycle::passive(),
    suspend_updaters: true,
  }
}

///|
fn ActiveAnimation::transform(
  id : ObjectId,
  start~ : @object.Object,
  target~ : @object.Object,
  timing~ : Timing,
) -> ActiveAnimation {
  ActiveAnimation::transform_with_lifecycle(
    id,
    start~,
    target~,
    timing~,
    lifecycle=AnimationLifecycle::new(
      introducer=false,
      remover=false,
      has_frame_effect=true,
    ),
  )
}

///|
fn ActiveAnimation::transform_with_lifecycle(
  id : ObjectId,
  start~ : @object.Object,
  target~ : @object.Object,
  timing~ : Timing,
  lifecycle~ : AnimationLifecycle,
) -> ActiveAnimation {
  {
    kind: ActiveTransform(id, start~, target~),
    timing,
    run_time: timing.resolve_run_time(1.0),
    lifecycle,
    suspend_updaters: true,
  }
}

///|
fn ActiveAnimation::scale(
  id : ObjectId,
  start~ : @object.Object,
  spec~ : ScaleSpec,
  timing~ : Timing,
) -> ActiveAnimation {
  {
    kind: ActiveScale(id, start~, spec~),
    timing,
    run_time: timing.resolve_run_time(1.0),
    lifecycle: AnimationLifecycle::new(
      introducer=false,
      remover=false,
      has_frame_effect=true,
    ),
    suspend_updaters: true,
  }
}

///|
fn ActiveAnimation::rotate(
  id : ObjectId,
  start~ : @object.Object,
  spec~ : RotationSpec,
  timing~ : Timing,
) -> ActiveAnimation {
  {
    kind: ActiveRotate(id, start~, spec~),
    timing,
    run_time: timing.resolve_run_time(1.0),
    lifecycle: AnimationLifecycle::new(
      introducer=false,
      remover=false,
      has_frame_effect=true,
    ),
    suspend_updaters: true,
  }
}

///|
fn ActiveAnimation::reveal(
  id : ObjectId,
  source~ : @object.Object,
  timing~ : Timing,
) -> ActiveAnimation {
  {
    kind: ActiveReveal(id, source~, family_size=create_family_size(source)),
    timing,
    run_time: timing.resolve_run_time(1.0),
    lifecycle: AnimationLifecycle::new(
      introducer=true,
      remover=false,
      has_frame_effect=true,
    ),
    suspend_updaters: true,
  }
}

///|
fn ActiveAnimation::fade_in(
  id : ObjectId,
  source~ : @object.Object,
  spec~ : FadeSpec,
  timing~ : Timing,
) -> ActiveAnimation {
  ActiveAnimation::transform_with_lifecycle(
    id,
    start=make_faded_object(source, spec, fade_in=true),
    target=source,
    timing~,
    lifecycle=AnimationLifecycle::new(
      introducer=true,
      remover=false,
      has_frame_effect=true,
    ),
  )
}

///|
fn ActiveAnimation::fade_out(
  id : ObjectId,
  source~ : @object.Object,
  spec~ : FadeSpec,
  timing~ : Timing,
) -> ActiveAnimation {
  ActiveAnimation::transform_with_lifecycle(
    id,
    start=source,
    target=make_faded_object(source, spec, fade_in=false),
    timing~,
    lifecycle=AnimationLifecycle::new(
      introducer=false,
      remover=true,
      has_frame_effect=true,
    ),
  )
}

///|
fn ActiveAnimation::draw_border_then_fill(
  id : ObjectId,
  source~ : @object.Object,
  timing~ : Timing,
  natural_run_time? : Double = 2.0,
) -> ActiveAnimation {
  let family_size = create_family_size(source)
  {
    kind: ActiveDrawBorderThenFill(
      id,
      source~,
      outline=make_outline_object(source),
      family_size~,
    ),
    timing,
    run_time: timing.resolve_run_time(natural_run_time),
    lifecycle: AnimationLifecycle::new(
      introducer=true,
      remover=false,
      has_frame_effect=true,
    ),
    suspend_updaters: true,
  }
}

///|
fn ActiveAnimation::group(
  scene : Scene,
  animations : Array[Animation],
  timing~ : Timing,
  replacement? : ReplacementFinish,
) -> ActiveAnimation raise SceneError {
  let children = animations.map(animation => {
    ActiveAnimation::compile(scene, animation)
  })
  validate_animation_targets(scene, children)
  let scheduled = schedule_group_children(children, timing.lag_ratio)
  let natural_run_time = scheduled.fold(init=0.0, (duration, child) => {
    if child.end_time > duration {
      child.end_time
    } else {
      duration
    }
  })
  {
    kind: ActiveGroup(scheduled, natural_run_time~, replacement~),
    timing,
    run_time: timing.resolve_run_time(natural_run_time),
    lifecycle: group_lifecycle(scheduled, replacement),
    suspend_updaters: true,
  }
}

///|
fn validate_animation_targets(
  scene : Scene,
  animations : Array[ActiveAnimation],
) -> Unit raise SceneError {
  for first_index in 0..<animations.length() {
    guard animations.get(first_index) is Some(first_animation) else { continue }
    for second_index in (first_index + 1)..<animations.length() {
      guard animations.get(second_index) is Some(second_animation) else {
        continue
      }
      if first_animation.affects_camera() && second_animation.affects_camera() {
        raise ConflictingCameraAnimations
      }
      for first in first_animation.affected_values() {
        for second in second_animation.affected_values() {
          if first == second {
            raise ConflictingValueAnimations(first)
          }
        }
      }
      for first in first_animation.affected_ids() {
        for second in second_animation.affected_ids() {
          if scene.same_family_branch(first, second) {
            raise ConflictingFamilyAnimations(first, second)
          }
        }
      }
    }
  }
}

///|
fn schedule_group_children(
  animations : Array[ActiveAnimation],
  lag_ratio : Double,
) -> Array[ActiveChild] {
  let scheduled : Array[ActiveChild] = []
  let mut start_time = 0.0
  for animation in animations {
    let run_time = animation.run_time()
    scheduled.push({ animation, start_time, end_time: start_time + run_time })
    start_time += run_time * lag_ratio
  }
  scheduled
}

///|
fn group_lifecycle(
  children : Array[ActiveChild],
  replacement : ReplacementFinish?,
) -> AnimationLifecycle {
  let lifecycle = children.fold(init=AnimationLifecycle::passive(), (
    lifecycle,
    child,
  ) => {
    introducer: lifecycle.introducer || child.animation.lifecycle.introducer,
    remover: lifecycle.remover || child.animation.lifecycle.remover,
    has_frame_effect: lifecycle.has_frame_effect ||
    child.animation.lifecycle.has_frame_effect,
  })
  match replacement {
    None => lifecycle
    Some(_) =>
      AnimationLifecycle::new(
        introducer=true,
        remover=true,
        has_frame_effect=true,
      )
  }
}

///|
fn ActiveAnimation::run_time(self : ActiveAnimation) -> Double {
  self.run_time
}

///|
fn ActiveAnimation::affected_ids(self : ActiveAnimation) -> Array[ObjectId] {
  match self.kind {
    ActiveWait | ActiveCamera(..) | ActiveValue(_, ..) => []
    ActiveTransform(id, ..)
    | ActiveScale(id, ..)
    | ActiveRotate(id, ..)
    | ActiveReveal(id, ..)
    | ActiveDrawBorderThenFill(id, ..) => [id]
    ActiveGroup(children, replacement~, ..) => {
      let ids = children
        .iter()
        .flat_map(child => child.animation.affected_ids().iter())
        .to_array()
      match replacement {
        None => ()
        Some(finish) => {
          ids.push(finish.source)
          ids.push(finish.target)
        }
      }
      ids
    }
  }
}

///|
fn ActiveAnimation::affected_values(
  self : ActiveAnimation,
) -> Array[ValueTracker] {
  match self.kind {
    ActiveValue(tracker, ..) => [tracker]
    ActiveGroup(children, ..) =>
      children
      .iter()
      .flat_map(child => child.animation.affected_values().iter())
      .to_array()
    _ => []
  }
}

///|
fn ActiveAnimation::affects_camera(self : ActiveAnimation) -> Bool {
  match self.kind {
    ActiveCamera(..) => true
    ActiveGroup(children, ..) =>
      children.any(child => child.animation.affects_camera())
    _ => false
  }
}

///|
fn ActiveAnimation::suspended_targets(
  self : ActiveAnimation,
  scene : Scene,
) -> Array[UpdateTarget] raise SceneError {
  if !self.suspend_updaters {
    []
  } else {
    match self.kind {
      ActiveWait => []
      ActiveCamera(..) => [CameraTarget]
      ActiveValue(tracker, ..) => [ValueTarget(tracker)]
      ActiveTransform(id, ..)
      | ActiveScale(id, ..)
      | ActiveRotate(id, ..)
      | ActiveReveal(id, ..)
      | ActiveDrawBorderThenFill(id, ..) =>
        scene.family(id).map(id => ObjectTarget(id))
      ActiveGroup(children, ..) => {
        let targets : Array[UpdateTarget] = []
        for child in children {
          targets.append(child.animation.suspended_targets(scene))
        }
        targets
      }
    }
  }
}

///|
fn ActiveAnimation::begin_patch(self : ActiveAnimation) -> FramePatch {
  let _ = self.lifecycle.introducer
  match self.kind {
    ActiveWait => FramePatch::empty()
    ActiveCamera(start~, ..) => FramePatch::set_camera(start)
    ActiveValue(tracker, start~, ..) => FramePatch::set_value(tracker, start)
    ActiveTransform(id, start~, ..) =>
      FramePatch::all([
        FramePatch::put(id, start),
        FramePatch::ensure_visible(id),
      ])
    ActiveScale(id, start~, ..) =>
      FramePatch::all([
        FramePatch::put(id, start),
        FramePatch::ensure_visible(id),
      ])
    ActiveRotate(id, start~, ..) =>
      FramePatch::all([
        FramePatch::put(id, start),
        FramePatch::ensure_visible(id),
      ])
    ActiveReveal(id, source~, family_size~) =>
      FramePatch::all([
        FramePatch::put(
          id,
          sample_create_object(source, 0.0, self.timing, family_size),
        ),
        FramePatch::ensure_visible(id),
      ])
    ActiveDrawBorderThenFill(id, source~, outline~, family_size~) =>
      FramePatch::all([
        FramePatch::put(
          id,
          sample_draw_border_then_fill(
            source,
            outline,
            0.0,
            self.timing,
            family_size,
          ),
        ),
        FramePatch::ensure_visible(id),
      ])
    ActiveGroup(children, ..) =>
      FramePatch::all(children.map(child => child.animation.begin_patch()))
  }
}

///|
fn ActiveAnimation::sample(
  self : ActiveAnimation,
  raw_alpha : Double,
) -> FramePatch {
  let raw_alpha = clamp_alpha(raw_alpha)
  let alpha = self.timing.apply_rate(raw_alpha)
  if !self.lifecycle.has_frame_effect {
    FramePatch::empty()
  } else {
    match self.kind {
      ActiveWait => FramePatch::empty()
      ActiveCamera(start~, target~) =>
        FramePatch::set_camera(start.interpolate(target, alpha))
      ActiveValue(tracker, start~, target~) =>
        FramePatch::set_value(tracker, lerp_double(start, target, alpha))
      ActiveTransform(id, start~, target~) =>
        FramePatch::all([
          FramePatch::put(id, interpolate_object(start, target, alpha)),
          FramePatch::ensure_visible(id),
        ])
      ActiveScale(id, start~, spec~) =>
        FramePatch::all([
          FramePatch::put(id, sample_scale_object(start, spec, alpha)),
          FramePatch::ensure_visible(id),
        ])
      ActiveRotate(id, start~, spec~) =>
        FramePatch::all([
          FramePatch::put(id, sample_rotate_object(start, spec, alpha)),
          FramePatch::ensure_visible(id),
        ])
      ActiveReveal(id, source~, family_size~) =>
        FramePatch::all([
          FramePatch::put(
            id,
            sample_create_object(source, raw_alpha, self.timing, family_size),
          ),
          FramePatch::ensure_visible(id),
        ])
      ActiveDrawBorderThenFill(id, source~, outline~, family_size~) =>
        FramePatch::all([
          FramePatch::put(
            id,
            sample_draw_border_then_fill(
              source,
              outline,
              raw_alpha,
              self.timing,
              family_size,
            ),
          ),
          FramePatch::ensure_visible(id),
        ])
      ActiveGroup(_, ..) => FramePatch::empty()
    }
  }
}

///|
fn ActiveAnimation::sample_at_time(
  self : ActiveAnimation,
  elapsed : Double,
) -> FramePatch {
  match self.kind {
    ActiveGroup(children, natural_run_time~, ..) =>
      self.sample_group_at_time(children, natural_run_time, elapsed)
    _ => self.sample(self.timing.raw_alpha_at_run_time(elapsed, self.run_time))
  }
}

///|
fn ActiveAnimation::finish_patch(self : ActiveAnimation) -> FramePatch {
  match self.kind {
    ActiveGroup(children, replacement~, ..) => {
      let finished = FramePatch::all(
        children.map(child => child.animation.finish_patch()),
      )
      match replacement {
        None => finished
        Some(finish) =>
          finished.then(
            FramePatch::all([
              FramePatch::hide(finish.source),
              FramePatch::show_subtree(finish.target),
            ]),
          )
      }
    }
    _ => {
      let final_sample = self.sample_at_time(self.run_time())
      if self.lifecycle.remover {
        final_sample.then(
          FramePatch::all(self.affected_ids().map(id => FramePatch::hide(id))),
        )
      } else {
        final_sample
      }
    }
  }
}

///|
fn ActiveAnimation::alpha_at_time(
  self : ActiveAnimation,
  elapsed : Double,
) -> Double {
  self.timing.alpha_at_run_time(elapsed, self.run_time)
}

///|
fn ActiveAnimation::sample_group_at_time(
  self : ActiveAnimation,
  children : Array[ActiveChild],
  natural_run_time : Double,
  elapsed : Double,
) -> FramePatch {
  let group_alpha = self.alpha_at_time(elapsed)
  let group_time = group_alpha * natural_run_time
  FramePatch::all(children.map(child => child.sample_at_group_time(group_time)))
}

///|
fn ActiveChild::sample_at_group_time(
  self : ActiveChild,
  group_time : Double,
) -> FramePatch {
  if group_time < self.start_time {
    FramePatch::empty()
  } else if group_time > self.end_time {
    self.animation.finish_patch()
  } else {
    self.animation.sample_at_time(group_time - self.start_time)
  }
}

///|
fn sample_create_object(
  source : @object.Object,
  raw_alpha : Double,
  timing : Timing,
  family_size : Int,
) -> @object.Object {
  sample_create_family_member(source, raw_alpha, timing, family_size, 0).0
}

///|
fn create_family_size(source : @object.Object) -> Int {
  match source.node {
    Empty => 0
    Path(_, _) | Mesh(_, _) => 1
    Group(children) =>
      children.fold(init=0, (size, child) => size + create_family_size(child))
  }
}

///|
fn sample_create_family_member(
  source : @object.Object,
  raw_alpha : Double,
  timing : Timing,
  family_size : Int,
  family_index : Int,
) -> (@object.Object, Int) {
  let (node, next_index) = match source.node {
    Empty => (@object.Empty, family_index)
    Path(path, style) => {
      let alpha = timing.family_alpha(raw_alpha, family_index, family_size)
      (Path(sample_create_path(path, alpha), style), family_index + 1)
    }
    Mesh(mesh, style) => {
      let alpha = timing.family_alpha(raw_alpha, family_index, family_size)
      (Mesh(mesh.prefix(alpha), style), family_index + 1)
    }
    Group(children) => {
      let sampled : Array[@object.Object] = []
      let mut next_index = family_index
      for child in children {
        let (next, after_child) = sample_create_family_member(
          child, raw_alpha, timing, family_size, next_index,
        )
        sampled.push(next)
        next_index = after_child
      }
      (Group(sampled), next_index)
    }
  }
  (
    @object.Object::new(
      node~,
      transform=source.transform,
      z_index=source.z_index,
    ),
    next_index,
  )
}

///|
fn sample_create_path(
  source : @object.Path3D,
  alpha : Double,
) -> @object.Path3D {
  source.eval().prefix(alpha).to_path() catch {
    _ => choose_endpoint(@object.Path3D::empty(), source, alpha)
  }
}

///|
fn sample_rotate_object(
  start : @object.Object,
  spec : RotationSpec,
  alpha : Double,
) -> @object.Object {
  let point = resolve_rotation_about_point(spec, start)
  let transform = @object.Transform::rotate_about(
    angle=spec.angle * alpha,
    axis=spec.axis,
    point~,
  )
  start.with_transform(start.transform.then(transform))
}

///|
fn sample_scale_object(
  start : @object.Object,
  spec : ScaleSpec,
  alpha : Double,
) -> @object.Object {
  let point = resolve_scale_about_point(spec, start)
  let transform = scale_about_transform(
    sx=lerp_double(1.0, spec.sx, alpha),
    sy=lerp_double(1.0, spec.sy, alpha),
    sz=lerp_double(1.0, spec.sz, alpha),
    point~,
  )
  start.with_transform(start.transform.then(transform))
}

///|
fn resolve_scale_about_point(
  spec : ScaleSpec,
  object : @object.Object,
) -> @object.Vec3 {
  match (spec.about_point, spec.about_edge) {
    (Some(point), _) => point
    (None, Some(edge)) => object.critical_point(edge)
    (None, None) => object.center()
  }
}

///|
fn scale_about_transform(
  sx~ : Double,
  sy~ : Double,
  sz~ : Double,
  point~ : @object.Vec3,
) -> @object.Transform {
  @object.Transform::translate(point.scale(-1.0))
  .then(@object.Transform::scale(sx~, sy~, sz~))
  .then(@object.Transform::translate(point))
}

///|
fn make_faded_object(
  source : @object.Object,
  spec : FadeSpec,
  fade_in~ : Bool,
) -> @object.Object {
  let (shift, point_target) = resolve_fade_shift(spec, source)
  let direction = if fade_in && !point_target { -1.0 } else { 1.0 }
  let shifted = source
    .set_fill(opacity=0.0)
    .set_stroke(opacity=0.0)
    .with_transform(
      source.transform.then(
        @object.Transform::translate(shift.scale(direction)),
      ),
    )
  if spec.scale == 1.0 {
    shifted
  } else {
    shifted.with_transform(
      shifted.transform.then(
        scale_about_transform(
          sx=spec.scale,
          sy=spec.scale,
          sz=spec.scale,
          point=shifted.center(),
        ),
      ),
    )
  }
}

///|
fn resolve_fade_shift(
  spec : FadeSpec,
  source : @object.Object,
) -> (@object.Vec3, Bool) {
  match (spec.shift, spec.target_position) {
    (Some(shift), _) => (shift, false)
    (None, Some(point)) => (point.sub(source.center()), true)
    (None, None) => (@object.Vec3::zero(), false)
  }
}

///|
fn resolve_rotation_about_point(
  spec : RotationSpec,
  object : @object.Object,
) -> @object.Vec3 {
  match (spec.about_point, spec.about_edge) {
    (Some(point), _) => point
    (None, Some(edge)) => object.critical_point(edge)
    (None, None) => object.center()
  }
}

///|
fn sample_draw_border_then_fill(
  source : @object.Object,
  outline : @object.Object,
  raw_alpha : Double,
  timing : Timing,
  family_size : Int,
) -> @object.Object {
  sample_draw_border_then_fill_member(
    source, outline, raw_alpha, timing, family_size, 0,
  ).0
}

///|
fn sample_draw_border_then_fill_member(
  source : @object.Object,
  outline : @object.Object,
  raw_alpha : Double,
  timing : Timing,
  family_size : Int,
  family_index : Int,
) -> (@object.Object, Int) {
  match (source.node, outline.node) {
    (Empty, _) => (source, family_index)
    (Path(_, _), Path(_, _)) | (Mesh(_, _), Mesh(_, _)) => {
      let alpha = timing.family_alpha(raw_alpha, family_index, family_size)
      let sampled = if alpha < 0.5 {
        sample_create_object(outline, alpha * 2.0, Timing::new(), 1)
      } else {
        interpolate_object(outline, source, (alpha - 0.5) * 2.0)
      }
      (sampled, family_index + 1)
    }
    (Group(source_children), Group(outline_children)) => {
      let sampled : Array[@object.Object] = []
      let mut next_index = family_index
      for index in 0..<source_children.length() {
        match (source_children.get(index), outline_children.get(index)) {
          (Some(source_child), Some(outline_child)) => {
            let (next, after_child) = sample_draw_border_then_fill_member(
              source_child, outline_child, raw_alpha, timing, family_size, next_index,
            )
            sampled.push(next)
            next_index = after_child
          }
          (Some(source_child), None) => {
            sampled.push(source_child)
            next_index = next_index + create_family_size(source_child)
          }
          _ => ()
        }
      }
      (
        @object.Object::new(
          node=Group(sampled),
          transform=source.transform,
          z_index=source.z_index,
        ),
        next_index,
      )
    }
    _ => (source, family_index + create_family_size(source))
  }
}

///|
fn write_default_run_time(family_size : Int) -> Double {
  if family_size < 15 {
    1.0
  } else {
    2.0
  }
}

///|
fn write_default_lag_ratio(family_size : Int) -> Double {
  let denominator = if family_size < 1 { 1.0 } else { family_size.to_double() }
  let ratio = 4.0 / denominator
  if ratio < 0.2 {
    ratio
  } else {
    0.2
  }
}

///|
fn make_outline_object(source : @object.Object) -> @object.Object {
  @object.Object::new(
    node=make_outline_node(source.node),
    transform=source.transform,
    z_index=source.z_index,
  )
}

///|
fn make_outline_node(source : @object.Node) -> @object.Node {
  match source {
    Empty => Empty
    Group(children) => Group(children.map(child => make_outline_object(child)))
    Path(path, style) => Path(path, make_outline_style(style))
    Mesh(mesh, style) => Mesh(mesh, make_outline_style(style))
  }
}

///|
fn make_outline_style(style : @object.ShapeStyle) -> @object.ShapeStyle {
  {
    fill: style.fill,
    fill_opacity: 0.0,
    stroke: make_outline_stroke(style),
    stroke_opacity: style.stroke_opacity,
    stroke_width: make_outline_stroke_width(style),
  }
}

///|
fn make_outline_stroke(style : @object.ShapeStyle) -> @object.Rgba? {
  match (style.stroke, style.fill) {
    (Some(stroke), _) => Some(stroke)
    (None, fill) => fill
  }
}

///|
fn make_outline_stroke_width(style : @object.ShapeStyle) -> Double {
  if style.stroke_width <= 0.0 {
    4.0
  } else {
    style.stroke_width
  }
}
