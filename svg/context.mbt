///|
priv struct SvgContext {
  style : SvgStyle
  transform : @object.Transform
  viewport : SvgViewport
  definitions : Map[String, @xml.XMLElement]
  references : Array[String]
}

///|
fn SvgContext::root(definitions : Map[String, @xml.XMLElement]) -> SvgContext {
  {
    style: SvgStyle::default(),
    transform: @object.Transform::identity(),
    viewport: SvgViewport::default(),
    definitions,
    references: [],
  }
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
