///|
pub(all) struct Timing {
  run_time : Double
}

///|
pub fn Timing::new(run_time? : Double = 1.0) -> Timing {
  { run_time, }
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
  FadeIn(ObjectId)
  FadeOut(ObjectId)
  Transform(ObjectId, @object.Object)
  ApplyOps(ObjectId, Array[ObjectOp])
}

///|
pub(all) struct Animation {
  kind : AnimationKind
  timing : Timing
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
pub fn Animation::create(id : ObjectId, run_time? : Double = 1.0) -> Animation {
  Animation::new(Create(id), timing=Timing::new(run_time~))
}

///|
pub fn Animation::fade_in(id : ObjectId, run_time? : Double = 1.0) -> Animation {
  Animation::new(FadeIn(id), timing=Timing::new(run_time~))
}

///|
pub fn Animation::fade_out(
  id : ObjectId,
  run_time? : Double = 1.0,
) -> Animation {
  Animation::new(FadeOut(id), timing=Timing::new(run_time~))
}

///|
pub fn[T : @object.IntoObject] Animation::transform(
  id : ObjectId,
  target : T,
  run_time? : Double = 1.0,
  name? : String = "",
) -> Animation {
  Animation::new(
    Transform(id, @object.into_object(target, id=name)),
    timing=Timing::new(run_time~),
  )
}

///|
pub fn Animation::apply_ops(
  id : ObjectId,
  ops : Array[ObjectOp],
  run_time? : Double = 1.0,
) -> Animation {
  Animation::new(ApplyOps(id, ops.copy()), timing=Timing::new(run_time~))
}

///|
pub fn Animation::with_run_time(
  self : Animation,
  run_time : Double,
) -> Animation {
  { kind: self.kind, timing: Timing::new(run_time~) }
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
) -> AnimationBuilder {
  { id: self, ops: [], timing: Timing::new(run_time~) }
}

///|
pub fn AnimationBuilder::with_run_time(
  self : AnimationBuilder,
  run_time : Double,
) -> AnimationBuilder {
  { id: self.id, ops: self.ops.copy(), timing: Timing::new(run_time~) }
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
  Animation::apply_ops(self.id, self.ops, run_time=self.timing.run_time)
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
