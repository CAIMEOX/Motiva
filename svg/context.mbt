///|
priv struct SvgContext {
  style : SvgStyle
  transform : @object.Transform
  viewport : SvgViewport
  definitions : Map[String, @xml.XMLElement]
  references : Array[String]
  groups : Map[String, Array[@object.FamilyPath]]
  diagnostics : Array[SvgDiagnostic]
  path : @object.FamilyPath
}

///|
fn SvgContext::root(
  definitions : Map[String, @xml.XMLElement],
  default_style : @object.ShapeStyle?,
  groups : Map[String, Array[@object.FamilyPath]],
  diagnostics : Array[SvgDiagnostic],
) -> SvgContext {
  {
    style: default_style.map_or(Default::default(), SvgStyle::from_shape_style),
    transform: @object.Transform::identity(),
    viewport: Default::default(),
    definitions,
    references: [],
    groups,
    diagnostics,
    path: @object.FamilyPath::root(),
  }
}

///|
fn SvgContext::at_child(self : SvgContext, index : Int) -> SvgContext {
  { ..self, path: self.path.child(index) }
}

///|
fn SvgContext::record_id(self : SvgContext, element : @xml.XMLElement) -> Unit {
  match element.get_attribute("id") {
    Some(id) if id != "" => {
      let paths = self.groups.get(id).map_or([], paths => paths)
      paths.push(self.path)
      self.groups[id] = paths
    }
    _ => ()
  }
}

///|
fn SvgContext::report_skipped(self : SvgContext, name : String) -> Unit {
  self.diagnostics.push(SkippedElement(name))
}

///|
fn SvgContext::enter_viewport(
  self : SvgContext,
  viewport : SvgViewport,
  transform : @object.Transform,
) -> SvgContext {
  { ..self, viewport, transform: transform.then(self.transform) }
}

///|
fn SvgContext::enter(
  self : SvgContext,
  style : SvgStyle,
  transform : @object.Transform,
) -> SvgContext {
  { ..self, style, transform: transform.then(self.transform) }
}

///|
fn SvgContext::translate(
  self : SvgContext,
  x : Double,
  y : Double,
) -> SvgContext {
  {
    ..self,
    transform: @object.Transform::translate(@object.Vec3::new(x~, y~)).then(
      self.transform,
    ),
  }
}

///|
fn SvgContext::follow(
  self : SvgContext,
  id : String,
) -> SvgContext raise SvgError {
  if self.references.contains(id) {
    raise CyclicReference(id)
  }
  let references = self.references.copy()
  references.push(id)
  { ..self, references, }
}
