///|
pub trait IntoObject {
  fn to_object(Self, id? : String) -> Object
}

///|
pub fn[T : IntoObject] into_object(value : T, id? : String = "") -> Object {
  value.to_object(id~)
}

///|
pub impl IntoObject for Object with fn to_object(self, id? : String = "") -> Object {
  { ..self, id, }
}
