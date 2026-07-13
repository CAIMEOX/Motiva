///|
pub(all) suberror SvgError {
  InvalidXml
  InvalidNumber(String)
  ExpectedNumber(String)
  MissingAttribute(element~ : String, attribute~ : String)
  InvalidColor(String)
  InvalidPathData(String)
  UnsupportedPathCommand(Char)
  InvalidTransform(String)
  UnsupportedElement(String)
}

///|
pub struct SvgObject {
  priv object : @object.Object
}

///|
pub fn SvgObject::object(self : SvgObject) -> @object.Object {
  self.object
}
