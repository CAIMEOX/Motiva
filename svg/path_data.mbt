///|
pub fn parse_path_data(data : String) -> @object.Path3D raise SvgError {
  let scanner = TextScanner::new(data)
  let path = @object.Path3D::empty()
  let mut command : Char? = None
  let mut current = @object.Vec3::zero()
  let mut subpath_start = @object.Vec3::zero()
  let mut has_current = false
  let mut previous_cubic_handle : @object.Vec3? = None
  let mut previous_quadratic_handle : @object.Vec3? = None
  while !scanner.is_done() {
    scanner.skip_comma_wsp()
    guard !scanner.is_done() else { break }
    match scanner.peek() {
      Some(char) if char.is_ascii_alphabetic() => {
        scanner.advance() |> ignore
        command = Some(char)
      }
      _ => ()
    }
    match command {
      None => raise InvalidPathData("path data must start with a command")
      Some('M') | Some('m') => {
        let is_relative = command == Some('m')
        let point = read_path_point(scanner, current, is_relative, "M")
        path.move_to(point)
        current = point
        subpath_start = point
        has_current = true
        command = if is_relative { Some('l') } else { Some('L') }
        previous_cubic_handle = None
        previous_quadratic_handle = None
      }
      Some('L') | Some('l') => {
        ensure_current(has_current)
        let point = read_path_point(scanner, current, command == Some('l'), "L")
        path.line_to(point)
        current = point
        previous_cubic_handle = None
        previous_quadratic_handle = None
      }
      Some('H') | Some('h') => {
        ensure_current(has_current)
        let x = scanner.read_required_number("H")
        let point = if command == Some('h') {
          @object.Vec3::new(x=current.x + x, y=current.y)
        } else {
          @object.Vec3::new(x~, y=current.y)
        }
        path.line_to(point)
        current = point
        previous_cubic_handle = None
        previous_quadratic_handle = None
      }
      Some('V') | Some('v') => {
        ensure_current(has_current)
        let y = scanner.read_required_number("V")
        let point = if command == Some('v') {
          @object.Vec3::new(x=current.x, y=current.y + y)
        } else {
          @object.Vec3::new(x=current.x, y~)
        }
        path.line_to(point)
        current = point
        previous_cubic_handle = None
        previous_quadratic_handle = None
      }
      Some('C') | Some('c') => {
        ensure_current(has_current)
        let is_relative = command == Some('c')
        let handle1 = read_path_point(scanner, current, is_relative, "C")
        let handle2 = read_path_point(scanner, current, is_relative, "C")
        let anchor = read_path_point(scanner, current, is_relative, "C")
        path.cubic_to(handle1, handle2, anchor)
        current = anchor
        previous_cubic_handle = Some(handle2)
        previous_quadratic_handle = None
      }
      Some('S') | Some('s') => {
        ensure_current(has_current)
        let is_relative = command == Some('s')
        let handle1 = previous_cubic_handle.map_or(current, previous => {
          current.add(current.sub(previous))
        })
        let handle2 = read_path_point(scanner, current, is_relative, "S")
        let anchor = read_path_point(scanner, current, is_relative, "S")
        path.cubic_to(handle1, handle2, anchor)
        current = anchor
        previous_cubic_handle = Some(handle2)
        previous_quadratic_handle = None
      }
      Some('Q') | Some('q') => {
        ensure_current(has_current)
        let is_relative = command == Some('q')
        let control = read_path_point(scanner, current, is_relative, "Q")
        let anchor = read_path_point(scanner, current, is_relative, "Q")
        append_quadratic(path, current, control, anchor)
        current = anchor
        previous_cubic_handle = None
        previous_quadratic_handle = Some(control)
      }
      Some('T') | Some('t') => {
        ensure_current(has_current)
        let is_relative = command == Some('t')
        let control = previous_quadratic_handle.map_or(current, previous => {
          current.add(current.sub(previous))
        })
        let anchor = read_path_point(scanner, current, is_relative, "T")
        append_quadratic(path, current, control, anchor)
        current = anchor
        previous_cubic_handle = None
        previous_quadratic_handle = Some(control)
      }
      Some('Z') | Some('z') => {
        ensure_current(has_current)
        path.close()
        current = subpath_start
        command = None
        previous_cubic_handle = None
        previous_quadratic_handle = None
      }
      Some(command) if command == 'A' || command == 'a' => {
        ensure_current(has_current)
        let is_relative = command == 'a'
        let radius_x = scanner.read_required_number("A")
        let radius_y = scanner.read_required_number("A")
        let rotation = scanner.read_required_number("A")
        let large_arc = read_arc_flag(scanner, "large-arc-flag")
        let sweep = read_arc_flag(scanner, "sweep-flag")
        let anchor = read_path_point(scanner, current, is_relative, "A")
        append_svg_arc(
          path,
          start=current,
          rx=radius_x,
          ry=radius_y,
          rotation~,
          large_arc~,
          sweep~,
          end=anchor,
        )
        current = anchor
        previous_cubic_handle = None
        previous_quadratic_handle = None
      }
      Some(char) => raise UnsupportedPathCommand(char)
    }
  }
  path
}

///|
fn ensure_current(has_current : Bool) -> Unit raise SvgError {
  if !has_current {
    raise InvalidPathData("path command requires a current point")
  }
}

///|
fn read_path_point(
  scanner : TextScanner,
  current : @object.Vec3,
  is_relative : Bool,
  context : String,
) -> @object.Vec3 raise SvgError {
  let x = scanner.read_required_number(context)
  let y = scanner.read_required_number(context)
  let point = @object.Vec3::new(x~, y~)
  if is_relative {
    current.add(point)
  } else {
    point
  }
}

///|
fn read_arc_flag(
  scanner : TextScanner,
  context : String,
) -> Bool raise SvgError {
  let flag = scanner.read_required_number(context)
  if flag == 0.0 {
    false
  } else if flag == 1.0 {
    true
  } else {
    raise InvalidPathData("\{context} must be 0 or 1")
  }
}

///|
fn append_quadratic(
  path : @object.Path3D,
  current : @object.Vec3,
  control : @object.Vec3,
  anchor : @object.Vec3,
) -> Unit {
  let handle1 = current.add(control.sub(current).scale(2.0 / 3.0))
  let handle2 = anchor.add(control.sub(anchor).scale(2.0 / 3.0))
  path.cubic_to(handle1, handle2, anchor)
}
