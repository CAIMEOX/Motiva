///|
pub(open) trait IntoObject {
  fn to_object(Self) -> Object
}

///|
pub fn[T : IntoObject] into_object(value : T) -> Object {
  value.to_object()
}

///|
pub impl IntoObject for Object with fn to_object(self) -> Object {
  self
}
