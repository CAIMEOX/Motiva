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
  InvalidLength(String)
  InvalidViewBox(String)
  UnsupportedElement(String)
  MissingReference(String)
  CyclicReference(String)
}

///|
pub struct SvgObject {
  priv object : @object.Object
}

///|
pub fn SvgObject::object(self : SvgObject) -> @object.Object {
  self.object
}

///|
pub fn SvgObject::copy(self : SvgObject) -> SvgObject {
  { object: copy_object(self.object) }
}

///|
fn copy_object(object : @object.Object) -> @object.Object {
  let node = match object.node {
    Empty => @object.Empty
    Group(children) => Group(children.map(copy_object))
    Path(path, style) => {
      let path_copy : @object.Path3D = { commands: path.commands.copy() }
      Path(path_copy, style)
    }
  }
  { ..object, node, }
}

///|
pub impl @object.IntoObject for SvgObject with fn to_object(self : SvgObject) -> @object.Object {
  self.object
}
