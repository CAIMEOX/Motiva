///|
priv struct AnimationLifecycle {
  introducer : Bool
  remover : Bool
  mutates_object : Bool
}

///|
priv enum RevealMode {
  CreateReveal
  FadeInReveal
}

///|
priv enum RemovalMode {
  FadeOutRemoval
}

///|
priv struct ActiveChild {
  animation : ActiveAnimation
  start_time : Double
  end_time : Double
}

///|
priv enum ActiveAnimationKind {
  ActiveWait
  ActiveTransform(ObjectId, start~ : @object.Object, target~ : @object.Object)
  ActiveScale(ObjectId, start~ : @object.Object, spec~ : ScaleSpec)
  ActiveRotate(ObjectId, start~ : @object.Object, spec~ : RotationSpec)
  ActiveReveal(ObjectId, source~ : @object.Object, mode~ : RevealMode)
  ActiveDrawBorderThenFill(
    ObjectId,
    source~ : @object.Object,
    outline~ : @object.Object
  )
  ActiveRemoval(ObjectId, source~ : @object.Object, mode~ : RemovalMode)
  ActiveGroup(Array[ActiveChild], natural_run_time~ : Double)
}

///|
priv struct ActiveAnimation {
  kind : ActiveAnimationKind
  timing : Timing
  run_time : Double
  lifecycle : AnimationLifecycle
}

///|
fn AnimationLifecycle::new(
  introducer~ : Bool,
  remover~ : Bool,
  mutates_object~ : Bool,
) -> AnimationLifecycle {
  { introducer, remover, mutates_object }
}

///|
fn AnimationLifecycle::passive() -> AnimationLifecycle {
  AnimationLifecycle::new(introducer=false, remover=false, mutates_object=false)
}

///|
fn ActiveAnimation::compile(
  scene : Scene,
  animation : Animation,
) -> ActiveAnimation raise SceneError {
  match animation.kind {
    Wait => ActiveAnimation::wait(animation.timing)
    Create(id) =>
      ActiveAnimation::reveal(
        id,
        source=scene.require_object(id).object,
        mode=CreateReveal,
        timing=animation.timing,
      )
    DrawBorderThenFill(id) =>
      ActiveAnimation::draw_border_then_fill(
        id,
        source=scene.require_object(id).object,
        timing=animation.timing,
      )
    Scale(id, spec) =>
      ActiveAnimation::scale(
        id,
        start=scene.require_object(id).object,
        spec~,
        timing=animation.timing,
      )
    Rotate(id, spec) =>
      ActiveAnimation::rotate(
        id,
        start=scene.require_object(id).object,
        spec~,
        timing=animation.timing,
      )
    FadeIn(id) =>
      ActiveAnimation::reveal(
        id,
        source=scene.require_object(id).object,
        mode=FadeInReveal,
        timing=animation.timing,
      )
    FadeOut(id) =>
      ActiveAnimation::removal(
        id,
        source=scene.require_object(id).object,
        mode=FadeOutRemoval,
        timing=animation.timing,
      )
    Transform(id, target) =>
      ActiveAnimation::transform(
        id,
        start=scene.require_object(id).object,
        target~,
        timing=animation.timing,
      )
    ApplyOps(id, ops) => {
      let start = scene.require_object(id).object
      let target = ops.fold(init=start, (object, op) => op.apply(object))
      ActiveAnimation::transform(id, start~, target~, timing=animation.timing)
    }
    Group(group) =>
      ActiveAnimation::group(scene, group.animations, timing=animation.timing)
  }
}

///|
fn ActiveAnimation::wait(timing : Timing) -> ActiveAnimation {
  {
    kind: ActiveWait,
    timing,
    run_time: timing.resolve_run_time(1.0),
    lifecycle: AnimationLifecycle::passive(),
  }
}

///|
fn ActiveAnimation::transform(
  id : ObjectId,
  start~ : @object.Object,
  target~ : @object.Object,
  timing~ : Timing,
) -> ActiveAnimation {
  {
    kind: ActiveTransform(id, start~, target~),
    timing,
    run_time: timing.resolve_run_time(1.0),
    lifecycle: AnimationLifecycle::new(
      introducer=false,
      remover=false,
      mutates_object=true,
    ),
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
      mutates_object=true,
    ),
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
      mutates_object=true,
    ),
  }
}

///|
fn ActiveAnimation::reveal(
  id : ObjectId,
  source~ : @object.Object,
  mode~ : RevealMode,
  timing~ : Timing,
) -> ActiveAnimation {
  {
    kind: ActiveReveal(id, source~, mode~),
    timing,
    run_time: timing.resolve_run_time(1.0),
    lifecycle: AnimationLifecycle::new(
      introducer=true,
      remover=false,
      mutates_object=true,
    ),
  }
}

///|
fn ActiveAnimation::draw_border_then_fill(
  id : ObjectId,
  source~ : @object.Object,
  timing~ : Timing,
) -> ActiveAnimation {
  {
    kind: ActiveDrawBorderThenFill(
      id,
      source~,
      outline=make_outline_object(source),
    ),
    timing,
    run_time: timing.resolve_run_time(1.0),
    lifecycle: AnimationLifecycle::new(
      introducer=true,
      remover=false,
      mutates_object=true,
    ),
  }
}

///|
fn ActiveAnimation::removal(
  id : ObjectId,
  source~ : @object.Object,
  mode~ : RemovalMode,
  timing~ : Timing,
) -> ActiveAnimation {
  {
    kind: ActiveRemoval(id, source~, mode~),
    timing,
    run_time: timing.resolve_run_time(1.0),
    lifecycle: AnimationLifecycle::new(
      introducer=false,
      remover=true,
      mutates_object=true,
    ),
  }
}

///|
fn ActiveAnimation::group(
  scene : Scene,
  animations : Array[Animation],
  timing~ : Timing,
) -> ActiveAnimation raise SceneError {
  let children = animations.map(animation => {
    ActiveAnimation::compile(scene, animation)
  })
  let scheduled = schedule_group_children(children, timing.lag_ratio)
  let natural_run_time = scheduled.fold(init=0.0, (duration, child) => {
    if child.end_time > duration {
      child.end_time
    } else {
      duration
    }
  })
  {
    kind: ActiveGroup(scheduled, natural_run_time~),
    timing,
    run_time: timing.resolve_run_time(natural_run_time),
    lifecycle: group_lifecycle(scheduled),
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
fn group_lifecycle(children : Array[ActiveChild]) -> AnimationLifecycle {
  children.fold(init=AnimationLifecycle::passive(), (lifecycle, child) => {
    introducer: lifecycle.introducer || child.animation.lifecycle.introducer,
    remover: lifecycle.remover || child.animation.lifecycle.remover,
    mutates_object: lifecycle.mutates_object ||
    child.animation.lifecycle.mutates_object,
  })
}

///|
fn ActiveAnimation::run_time(self : ActiveAnimation) -> Double {
  self.run_time
}

///|
fn ActiveAnimation::affected_ids(self : ActiveAnimation) -> Array[ObjectId] {
  match self.kind {
    ActiveWait => []
    ActiveTransform(id, ..)
    | ActiveScale(id, ..)
    | ActiveRotate(id, ..)
    | ActiveReveal(id, ..)
    | ActiveDrawBorderThenFill(id, ..)
    | ActiveRemoval(id, ..) => [id]
    ActiveGroup(children, ..) =>
      children.fold(init=[], (ids, child) => {
        let next = ids.copy()
        next.append(child.animation.affected_ids())
        next
      })
  }
}

///|
fn ActiveAnimation::begin_patch(self : ActiveAnimation) -> FramePatch {
  let _ = self.lifecycle.introducer
  match self.kind {
    ActiveWait => FramePatch::empty()
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
    ActiveReveal(id, source~, mode~) =>
      FramePatch::all([
        FramePatch::put(id, sample_reveal(source, mode, 0.0)),
        FramePatch::ensure_visible(id),
      ])
    ActiveDrawBorderThenFill(id, source~, outline~) =>
      FramePatch::all([
        FramePatch::put(id, sample_draw_border_then_fill(source, outline, 0.0)),
        FramePatch::ensure_visible(id),
      ])
    ActiveRemoval(id, source~, ..) =>
      FramePatch::all([
        FramePatch::put(id, source),
        FramePatch::ensure_visible(id),
      ])
    ActiveGroup(children, ..) =>
      FramePatch::all(children.map(child => child.animation.begin_patch()))
  }
}

///|
fn ActiveAnimation::sample(
  self : ActiveAnimation,
  alpha : Double,
) -> FramePatch {
  let alpha = clamp_alpha(alpha)
  if !self.lifecycle.mutates_object {
    FramePatch::empty()
  } else {
    match self.kind {
      ActiveWait => FramePatch::empty()
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
      ActiveReveal(id, source~, mode~) =>
        FramePatch::all([
          FramePatch::put(id, sample_reveal(source, mode, alpha)),
          FramePatch::ensure_visible(id),
        ])
      ActiveDrawBorderThenFill(id, source~, outline~) =>
        FramePatch::all([
          FramePatch::put(
            id,
            sample_draw_border_then_fill(source, outline, alpha),
          ),
          FramePatch::ensure_visible(id),
        ])
      ActiveRemoval(id, source~, mode~) =>
        FramePatch::all([
          FramePatch::put(id, sample_removal(source, mode, alpha)),
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
    ActiveGroup(children, natural_run_time~) =>
      self.sample_group_at_time(children, natural_run_time, elapsed)
    _ => self.sample(self.alpha_at_time(elapsed))
  }
}

///|
fn ActiveAnimation::finish_patch(self : ActiveAnimation) -> FramePatch {
  match self.kind {
    ActiveGroup(children, ..) =>
      FramePatch::all(children.map(child => child.animation.finish_patch()))
    _ => {
      let final_sample = self.sample_at_time(self.run_time())
      if self.lifecycle.remover {
        match self.kind {
          ActiveRemoval(id, ..) => final_sample.then(FramePatch::hide(id))
          _ => final_sample
        }
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
fn sample_reveal(
  source : @object.Object,
  mode : RevealMode,
  alpha : Double,
) -> @object.Object {
  match mode {
    CreateReveal => sample_create_object(source, alpha)
    FadeInReveal => source
  }
}

///|
fn sample_create_object(
  source : @object.Object,
  alpha : Double,
) -> @object.Object {
  @object.Object::new(
    node=sample_create_node(source.node, alpha),
    id=source.id,
    transform=source.transform,
    z_index=source.z_index,
  )
}

///|
fn sample_create_node(source : @object.Node, alpha : Double) -> @object.Node {
  match source {
    Empty => Empty
    Group(children) =>
      Group(children.map(child => sample_create_object(child, alpha)))
    Path(path, style) => Path(sample_create_path(path, alpha), style)
  }
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
  alpha : Double,
) -> @object.Object {
  if alpha < 0.5 {
    sample_create_object(outline, alpha * 2.0)
  } else {
    interpolate_object(outline, source, (alpha - 0.5) * 2.0)
  }
}

///|
fn make_outline_object(source : @object.Object) -> @object.Object {
  @object.Object::new(
    node=make_outline_node(source.node),
    id=source.id,
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

///|
fn sample_removal(
  source : @object.Object,
  mode : RemovalMode,
  _alpha : Double,
) -> @object.Object {
  match mode {
    FadeOutRemoval => source
  }
}
