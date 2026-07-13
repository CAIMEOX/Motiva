///|
priv struct SvgViewBox {
  min_x : Double
  min_y : Double
  width : Double
  height : Double
}

///|
priv enum SvgAlign {
  AlignMin
  AlignMid
  AlignMax
}

///|
priv enum SvgAspectRatio {
  Stretch
  Uniform(SvgAlign, SvgAlign, Bool)
}

///|
fn parse_view_box(element : @xml.XMLElement) -> SvgViewBox? raise SvgError {
  match element.get_attribute("viewBox") {
    None => None
    Some(value) => {
      let scanner = TextScanner::new(value)
      let min_x = scanner.read_required_number("viewBox")
      let min_y = scanner.read_required_number("viewBox")
      let width = scanner.read_required_number("viewBox")
      let height = scanner.read_required_number("viewBox")
      scanner.skip_comma_wsp()
      if !scanner.is_done() || width <= 0.0 || height <= 0.0 {
        raise InvalidViewBox(value)
      }
      Some({ min_x, min_y, width, height })
    }
  }
}

///|
fn parse_aspect_ratio(
  element : @xml.XMLElement,
) -> SvgAspectRatio raise SvgError {
  match element.get_attribute("preserveAspectRatio") {
    None => Uniform(AlignMid, AlignMid, false)
    Some(value) => {
      let parts : Array[String] = []
      for part in value.split(" ") {
        let part = part.trim().to_owned()
        if part != "" && part != "defer" {
          parts.push(part)
        }
      }
      match parts {
        ["none"] => Stretch
        [alignment] => parse_uniform_aspect(alignment, false, value)
        [alignment, "meet"] => parse_uniform_aspect(alignment, false, value)
        [alignment, "slice"] => parse_uniform_aspect(alignment, true, value)
        _ => raise InvalidViewBox(value)
      }
    }
  }
}

///|
fn parse_uniform_aspect(
  alignment : String,
  slice : Bool,
  context : String,
) -> SvgAspectRatio raise SvgError {
  match alignment {
    "xMinYMin" => Uniform(AlignMin, AlignMin, slice)
    "xMidYMin" => Uniform(AlignMid, AlignMin, slice)
    "xMaxYMin" => Uniform(AlignMax, AlignMin, slice)
    "xMinYMid" => Uniform(AlignMin, AlignMid, slice)
    "xMidYMid" => Uniform(AlignMid, AlignMid, slice)
    "xMaxYMid" => Uniform(AlignMax, AlignMid, slice)
    "xMinYMax" => Uniform(AlignMin, AlignMax, slice)
    "xMidYMax" => Uniform(AlignMid, AlignMax, slice)
    "xMaxYMax" => Uniform(AlignMax, AlignMax, slice)
    _ => raise InvalidViewBox(context)
  }
}

///|
fn viewport_transform(
  viewport : SvgViewport,
  view_box : SvgViewBox?,
  aspect_ratio : SvgAspectRatio,
  x : Double,
  y : Double,
) -> @object.Transform {
  match view_box {
    None => @object.Transform::translate(@object.Vec3::new(x~, y~))
    Some(view_box) => {
      let sx = viewport.width / view_box.width
      let sy = viewport.height / view_box.height
      let (scale_x, scale_y, offset_x, offset_y) = match aspect_ratio {
        Stretch => (sx, sy, 0.0, 0.0)
        Uniform(align_x, align_y, slice) => {
          let scale = if slice {
            Double::max(sx, sy)
          } else {
            Double::min(sx, sy)
          }
          (
            scale,
            scale,
            align_offset(viewport.width - view_box.width * scale, align_x),
            align_offset(viewport.height - view_box.height * scale, align_y),
          )
        }
      }
      @object.Transform::translate(
        @object.Vec3::new(x=0.0 - view_box.min_x, y=0.0 - view_box.min_y),
      )
      .then(@object.Transform::scale(sx=scale_x, sy=scale_y))
      .then(
        @object.Transform::translate(
          @object.Vec3::new(x=x + offset_x, y=y + offset_y),
        ),
      )
    }
  }
}

///|
fn align_offset(extra : Double, alignment : SvgAlign) -> Double {
  match alignment {
    AlignMin => 0.0
    AlignMid => extra / 2.0
    AlignMax => extra
  }
}
