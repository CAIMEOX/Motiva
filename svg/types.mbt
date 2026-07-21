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
pub(all) enum SvgDiagnostic {
  SkippedElement(String)
} derive(Eq, Debug)

///|
pub struct SvgObject {
  priv object : @object.Object
  priv groups : Map[String, Array[@object.FamilyPath]]
  priv diagnostics : Array[SvgDiagnostic]
}

///|
pub fn SvgObject::object(self : SvgObject) -> @object.Object {
  self.object
}

///|
pub fn SvgObject::group_paths(
  self : SvgObject,
  id : String,
) -> Array[@object.FamilyPath] {
  self.groups.get(id).map_or([], paths => paths.copy())
}

///|
pub fn SvgObject::diagnostics(self : SvgObject) -> Array[SvgDiagnostic] {
  self.diagnostics.copy()
}

///|
pub fn SvgObject::copy(self : SvgObject) -> SvgObject {
  {
    object: copy_object(self.object),
    groups: copy_group_index(self.groups),
    diagnostics: self.diagnostics.copy(),
  }
}

///|
fn copy_group_index(
  groups : Map[String, Array[@object.FamilyPath]],
) -> Map[String, Array[@object.FamilyPath]] {
  let copied : Map[String, Array[@object.FamilyPath]] = {}
  for entry in groups {
    let (id, paths) = entry
    copied[id] = paths.copy()
  }
  copied
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
    Mesh(mesh, style) => Mesh(mesh.map_vertices(point => point), style)
  }
  { ..object, node, }
}

///|
fn apply_override_style(
  object : @object.Object,
  style : @object.ShapeStyle,
) -> @object.Object {
  let node = match object.node {
    Empty => @object.Empty
    Group(children) =>
      Group(children.map(child => apply_override_style(child, style)))
    Path(path, _) => Path(path, style)
    Mesh(mesh, _) => Mesh(mesh, style)
  }
  { ..object, node, }
}

///|
pub impl @object.IntoObject for SvgObject with fn to_object(self : SvgObject) -> @object.Object {
  self.object
}
