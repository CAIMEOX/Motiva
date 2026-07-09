///|
pub(all) enum RateFunc {
  Linear
  Smooth
  RushInto
  RushFrom
  SlowInto
  DoubleSmooth
  ThereAndBack
  Custom((Double) -> Double)
}

///|
pub fn RateFunc::sample(self : RateFunc, t : Double) -> Double {
  let t = clamp_unit(t)
  match self {
    Linear => t
    Smooth => smooth_rate(t)
    RushInto => 2.0 * smooth_rate(0.5 * t)
    RushFrom => 2.0 * smooth_rate(0.5 * (t + 1.0)) - 1.0
    SlowInto => @math.pow(1.0 - (1.0 - t) * (1.0 - t), 0.5)
    DoubleSmooth =>
      if t < 0.5 {
        0.5 * smooth_rate(2.0 * t)
      } else {
        0.5 * (1.0 + smooth_rate(2.0 * t - 1.0))
      }
    ThereAndBack =>
      if t < 0.5 {
        smooth_rate(2.0 * t)
      } else {
        smooth_rate(2.0 * (1.0 - t))
      }
    Custom(f) => f(t)
  }
}

///|
fn clamp_unit(t : Double) -> Double {
  if t.is_nan() || t < 0.0 {
    0.0
  } else if t > 1.0 {
    1.0
  } else {
    t
  }
}

///|
fn smooth_rate(t : Double) -> Double {
  let inflection = 10.0
  let error = sigmoid(-0.5 * inflection)
  (sigmoid(inflection * (t - 0.5)) - error) / (1.0 - 2.0 * error)
}

///|
fn sigmoid(x : Double) -> Double {
  1.0 / (1.0 + @math.exp(-x))
}

///|
pub(all) enum RunTime {
  Auto
  Fixed(Double)
}

///|
pub fn RunTime::resolve(self : RunTime, natural : Double) -> Double {
  match self {
    Auto => natural
    Fixed(seconds) => seconds
  }
}

///|
pub(all) struct Timing {
  run_time : RunTime
  rate_func : RateFunc
  reverse_rate_function : Bool
  lag_ratio : Double
}

///|
pub fn Timing::new(
  run_time? : Double = 1.0,
  rate_func? : RateFunc = Linear,
  reverse_rate_function? : Bool = false,
  lag_ratio? : Double = 0.0,
) -> Timing {
  { run_time: Fixed(run_time), rate_func, reverse_rate_function, lag_ratio }
}

///|
pub fn Timing::auto(
  rate_func? : RateFunc = Linear,
  reverse_rate_function? : Bool = false,
  lag_ratio? : Double = 0.0,
) -> Timing {
  { run_time: Auto, rate_func, reverse_rate_function, lag_ratio }
}

///|
pub fn Timing::resolve_run_time(self : Timing, natural : Double) -> Double {
  self.run_time.resolve(natural)
}

///|
pub fn Timing::raw_alpha_at(self : Timing, elapsed : Double) -> Double {
  self.raw_alpha_at_run_time(elapsed, self.resolve_run_time(1.0))
}

///|
fn Timing::raw_alpha_at_run_time(
  _self : Timing,
  elapsed : Double,
  run_time : Double,
) -> Double {
  if run_time <= 0.0 {
    1.0
  } else {
    clamp_unit(elapsed / run_time)
  }
}

///|
pub fn Timing::alpha_at(self : Timing, elapsed : Double) -> Double {
  self.alpha_at_run_time(elapsed, self.resolve_run_time(1.0))
}

///|
fn Timing::alpha_at_run_time(
  self : Timing,
  elapsed : Double,
  run_time : Double,
) -> Double {
  let raw_alpha = self.raw_alpha_at_run_time(elapsed, run_time)
  let local_alpha = if self.reverse_rate_function {
    1.0 - raw_alpha
  } else {
    raw_alpha
  }
  self.rate_func.sample(local_alpha)
}

///|
pub fn Timing::with_run_time(self : Timing, run_time : Double) -> Timing {
  {
    run_time: Fixed(run_time),
    rate_func: self.rate_func,
    reverse_rate_function: self.reverse_rate_function,
    lag_ratio: self.lag_ratio,
  }
}

///|
pub fn Timing::with_auto_run_time(self : Timing) -> Timing {
  {
    run_time: Auto,
    rate_func: self.rate_func,
    reverse_rate_function: self.reverse_rate_function,
    lag_ratio: self.lag_ratio,
  }
}

///|
pub fn Timing::with_rate_func(self : Timing, rate_func : RateFunc) -> Timing {
  {
    run_time: self.run_time,
    rate_func,
    reverse_rate_function: self.reverse_rate_function,
    lag_ratio: self.lag_ratio,
  }
}

///|
pub fn Timing::with_lag_ratio(self : Timing, lag_ratio : Double) -> Timing {
  {
    run_time: self.run_time,
    rate_func: self.rate_func,
    reverse_rate_function: self.reverse_rate_function,
    lag_ratio,
  }
}

///|
pub(all) struct RotationSpec {
  angle : Double
  axis : @object.Vec3
  about_point : @object.Vec3?
  about_edge : @object.Vec3?
}

///|
pub fn RotationSpec::new(
  angle? : Double = @math.PI,
  axis? : @object.Vec3 = @object.Vec3::unit_z(),
  about_point? : @object.Vec3,
  about_edge? : @object.Vec3,
) -> RotationSpec {
  { angle, axis, about_point, about_edge }
}

///|
pub(all) struct ScaleSpec {
  sx : Double
  sy : Double
  sz : Double
  about_point : @object.Vec3?
  about_edge : @object.Vec3?
}

///|
pub fn ScaleSpec::new(
  sx~ : Double,
  sy~ : Double,
  sz? : Double = 1.0,
  about_point? : @object.Vec3,
  about_edge? : @object.Vec3,
) -> ScaleSpec {
  { sx, sy, sz, about_point, about_edge }
}

///|
pub(all) enum ObjectOp {
  ApplyTransform(@object.Transform)
  SetTransform(@object.Transform)
  SetZIndex(Double)
}

///|
pub fn ObjectOp::shift(offset : @object.Vec3) -> ObjectOp {
  ApplyTransform(@object.Transform::translate(offset))
}

///|
pub fn ObjectOp::scale(
  sx~ : Double,
  sy~ : Double,
  sz? : Double = 1.0,
) -> ObjectOp {
  ApplyTransform(@object.Transform::scale(sx~, sy~, sz~))
}

///|
pub fn ObjectOp::rotate(angle~ : Double) -> ObjectOp {
  ApplyTransform(@object.Transform::rotate(angle~))
}

///|
pub fn ObjectOp::rotate_x(angle~ : Double) -> ObjectOp {
  ApplyTransform(@object.Transform::rotate_x(angle~))
}

///|
pub fn ObjectOp::rotate_y(angle~ : Double) -> ObjectOp {
  ApplyTransform(@object.Transform::rotate_y(angle~))
}

///|
pub fn ObjectOp::rotate_z(angle~ : Double) -> ObjectOp {
  ApplyTransform(@object.Transform::rotate_z(angle~))
}

///|
pub fn ObjectOp::set_transform(transform : @object.Transform) -> ObjectOp {
  SetTransform(transform)
}

///|
pub fn ObjectOp::set_z_index(z_index : Double) -> ObjectOp {
  SetZIndex(z_index)
}

///|
pub fn ObjectOp::apply(
  self : ObjectOp,
  object : @object.Object,
) -> @object.Object {
  match self {
    ApplyTransform(transform) =>
      object.with_transform(object.transform.then(transform))
    SetTransform(transform) => object.with_transform(transform)
    SetZIndex(z_index) => object.with_z_index(z_index)
  }
}

///|
pub(all) enum AnimationKind {
  Wait
  Create(ObjectId)
  DrawBorderThenFill(ObjectId)
  Scale(ObjectId, ScaleSpec)
  Rotate(ObjectId, RotationSpec)
  FadeIn(ObjectId)
  FadeOut(ObjectId)
  Transform(ObjectId, @object.Object)
  ApplyOps(ObjectId, Array[ObjectOp])
  Group(AnimationGroup)
}

///|
pub(all) struct Animation {
  kind : AnimationKind
  timing : Timing
}

///|
pub(all) struct AnimationGroup {
  animations : Array[Animation]
}

///|
pub fn[T : IntoAnimation] AnimationGroup::new(
  animations : Array[T],
) -> AnimationGroup {
  { animations: animations.map(animation => into_animation(animation)) }
}

///|
pub fn Animation::new(
  kind : AnimationKind,
  timing? : Timing = Timing::new(),
) -> Animation {
  { kind, timing }
}

///|
pub fn Animation::wait(duration : Double) -> Animation {
  Animation::new(Wait, timing=Timing::new(run_time=duration))
}

///|
pub fn[T : IntoAnimation] Animation::group(
  animations : Array[T],
  run_time? : Double,
  rate_func? : RateFunc = Linear,
  reverse_rate_function? : Bool = false,
  lag_ratio? : Double = 0.0,
) -> Animation {
  let timing = match run_time {
    None => Timing::auto(rate_func~, reverse_rate_function~, lag_ratio~)
    Some(seconds) =>
      Timing::new(
        run_time=seconds,
        rate_func~,
        reverse_rate_function~,
        lag_ratio~,
      )
  }
  Animation::new(Group(AnimationGroup::new(animations)), timing~)
}

///|
pub fn[T : IntoAnimation] Animation::lagged_start(
  animations : Array[T],
  run_time? : Double,
  rate_func? : RateFunc = Linear,
  reverse_rate_function? : Bool = false,
  lag_ratio? : Double = 0.05,
) -> Animation {
  Animation::group(
    animations,
    run_time?,
    rate_func~,
    reverse_rate_function~,
    lag_ratio~,
  )
}

///|
pub fn Animation::create(
  id : ObjectId,
  run_time? : Double = 1.0,
  rate_func? : RateFunc = Linear,
  reverse_rate_function? : Bool = false,
) -> Animation {
  Animation::new(
    Create(id),
    timing=Timing::new(run_time~, rate_func~, reverse_rate_function~),
  )
}

///|
pub fn Animation::draw_border_then_fill(
  id : ObjectId,
  run_time? : Double = 2.0,
  rate_func? : RateFunc = Linear,
  reverse_rate_function? : Bool = false,
) -> Animation {
  Animation::new(
    DrawBorderThenFill(id),
    timing=Timing::new(run_time~, rate_func~, reverse_rate_function~),
  )
}

///|
pub fn Animation::scale(
  id : ObjectId,
  sx~ : Double,
  sy~ : Double,
  sz? : Double = 1.0,
  about_point? : @object.Vec3,
  about_edge? : @object.Vec3,
  run_time? : Double = 1.0,
  rate_func? : RateFunc = Linear,
  reverse_rate_function? : Bool = false,
) -> Animation {
  let spec = ScaleSpec::new(sx~, sy~, sz~, about_point?, about_edge?)
  Animation::new(
    Scale(id, spec),
    timing=Timing::new(run_time~, rate_func~, reverse_rate_function~),
  )
}

///|
pub fn Animation::rotate(
  id : ObjectId,
  angle? : Double = @math.PI,
  axis? : @object.Vec3 = @object.Vec3::unit_z(),
  about_point? : @object.Vec3,
  about_edge? : @object.Vec3,
  run_time? : Double = 1.0,
  rate_func? : RateFunc = Linear,
  reverse_rate_function? : Bool = false,
) -> Animation {
  let spec : RotationSpec = { angle, axis, about_point, about_edge }
  Animation::new(
    Rotate(id, spec),
    timing=Timing::new(run_time~, rate_func~, reverse_rate_function~),
  )
}

///|
pub fn Animation::fade_in(
  id : ObjectId,
  run_time? : Double = 1.0,
  rate_func? : RateFunc = Linear,
  reverse_rate_function? : Bool = false,
) -> Animation {
  Animation::new(
    FadeIn(id),
    timing=Timing::new(run_time~, rate_func~, reverse_rate_function~),
  )
}

///|
pub fn Animation::fade_out(
  id : ObjectId,
  run_time? : Double = 1.0,
  rate_func? : RateFunc = Linear,
  reverse_rate_function? : Bool = false,
) -> Animation {
  Animation::new(
    FadeOut(id),
    timing=Timing::new(run_time~, rate_func~, reverse_rate_function~),
  )
}

///|
pub fn[T : @object.IntoObject] Animation::transform(
  id : ObjectId,
  target : T,
  run_time? : Double = 1.0,
  rate_func? : RateFunc = Linear,
  reverse_rate_function? : Bool = false,
  name? : String = "",
) -> Animation {
  Animation::new(
    Transform(id, @object.into_object(target, id=name)),
    timing=Timing::new(run_time~, rate_func~, reverse_rate_function~),
  )
}

///|
pub fn Animation::apply_ops(
  id : ObjectId,
  ops : Array[ObjectOp],
  run_time? : Double = 1.0,
  rate_func? : RateFunc = Linear,
  reverse_rate_function? : Bool = false,
) -> Animation {
  Animation::new(
    ApplyOps(id, ops.copy()),
    timing=Timing::new(run_time~, rate_func~, reverse_rate_function~),
  )
}

///|
pub fn Animation::with_run_time(
  self : Animation,
  run_time : Double,
) -> Animation {
  { kind: self.kind, timing: self.timing.with_run_time(run_time) }
}

///|
pub fn Animation::with_rate_func(
  self : Animation,
  rate_func : RateFunc,
) -> Animation {
  { kind: self.kind, timing: self.timing.with_rate_func(rate_func) }
}

///|
pub fn Animation::with_lag_ratio(
  self : Animation,
  lag_ratio : Double,
) -> Animation {
  { kind: self.kind, timing: self.timing.with_lag_ratio(lag_ratio) }
}

///|
pub trait IntoAnimation {
  fn to_animation(Self) -> Animation
}

///|
pub fn[T : IntoAnimation] into_animation(animation : T) -> Animation {
  animation.to_animation()
}

///|
pub impl IntoAnimation for Animation with fn to_animation(self) {
  self
}

///|
pub(all) struct AnimationBuilder {
  id : ObjectId
  ops : Array[ObjectOp]
  timing : Timing
}

///|
pub fn ObjectId::animate(
  self : ObjectId,
  run_time? : Double = 1.0,
  rate_func? : RateFunc = Linear,
  reverse_rate_function? : Bool = false,
) -> AnimationBuilder {
  {
    id: self,
    ops: [],
    timing: Timing::new(run_time~, rate_func~, reverse_rate_function~),
  }
}

///|
pub fn AnimationBuilder::with_run_time(
  self : AnimationBuilder,
  run_time : Double,
) -> AnimationBuilder {
  {
    id: self.id,
    ops: self.ops.copy(),
    timing: self.timing.with_run_time(run_time),
  }
}

///|
pub fn AnimationBuilder::with_rate_func(
  self : AnimationBuilder,
  rate_func : RateFunc,
) -> AnimationBuilder {
  {
    id: self.id,
    ops: self.ops.copy(),
    timing: self.timing.with_rate_func(rate_func),
  }
}

///|
pub fn AnimationBuilder::shift(
  self : AnimationBuilder,
  offset : @object.Vec3,
) -> AnimationBuilder {
  self.with_op(ObjectOp::shift(offset))
}

///|
pub fn AnimationBuilder::scale(
  self : AnimationBuilder,
  sx~ : Double,
  sy~ : Double,
  sz? : Double = 1.0,
) -> AnimationBuilder {
  self.with_op(ObjectOp::scale(sx~, sy~, sz~))
}

///|
pub fn AnimationBuilder::rotate(
  self : AnimationBuilder,
  angle~ : Double,
) -> AnimationBuilder {
  self.with_op(ObjectOp::rotate(angle~))
}

///|
pub fn AnimationBuilder::rotate_x(
  self : AnimationBuilder,
  angle~ : Double,
) -> AnimationBuilder {
  self.with_op(ObjectOp::rotate_x(angle~))
}

///|
pub fn AnimationBuilder::rotate_y(
  self : AnimationBuilder,
  angle~ : Double,
) -> AnimationBuilder {
  self.with_op(ObjectOp::rotate_y(angle~))
}

///|
pub fn AnimationBuilder::rotate_z(
  self : AnimationBuilder,
  angle~ : Double,
) -> AnimationBuilder {
  self.with_op(ObjectOp::rotate_z(angle~))
}

///|
pub fn AnimationBuilder::set_transform(
  self : AnimationBuilder,
  transform : @object.Transform,
) -> AnimationBuilder {
  self.with_op(ObjectOp::set_transform(transform))
}

///|
pub fn AnimationBuilder::set_z_index(
  self : AnimationBuilder,
  z_index : Double,
) -> AnimationBuilder {
  self.with_op(ObjectOp::set_z_index(z_index))
}

///|
pub fn AnimationBuilder::target(
  self : AnimationBuilder,
  object : @object.Object,
) -> @object.Object {
  self.ops.fold(init=object, (current, op) => op.apply(current))
}

///|
pub fn AnimationBuilder::to_animation(self : AnimationBuilder) -> Animation {
  Animation::new(ApplyOps(self.id, self.ops.copy()), timing=self.timing)
}

///|
pub impl IntoAnimation for AnimationBuilder with fn to_animation(self) {
  self.to_animation()
}

///|
fn AnimationBuilder::with_op(
  self : AnimationBuilder,
  op : ObjectOp,
) -> AnimationBuilder {
  let ops = self.ops.copy()
  ops.push(op)
  { id: self.id, ops, timing: self.timing }
}
