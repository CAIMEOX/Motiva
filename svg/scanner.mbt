///|
priv struct TextScanner {
  source : String
  mut index : Int
}

///|
fn TextScanner::new(source : String) -> TextScanner {
  { source, index: 0 }
}

///|
fn TextScanner::is_done(self : TextScanner) -> Bool {
  self.index >= self.source.length()
}

///|
fn TextScanner::peek(self : TextScanner) -> Char? {
  self.source.get_char(self.index)
}

///|
fn TextScanner::advance(self : TextScanner) -> Char? {
  match self.peek() {
    None => None
    Some(char) => {
      self.index += char.utf16_len()
      Some(char)
    }
  }
}

///|
fn TextScanner::skip_wsp(self : TextScanner) -> Unit {
  while !self.is_done() {
    match self.peek() {
      Some(char) if char.is_ascii_whitespace() => self.advance() |> ignore
      _ => break
    }
  }
}

///|
fn TextScanner::skip_comma_wsp(self : TextScanner) -> Unit {
  while !self.is_done() {
    match self.peek() {
      Some(char) if char.is_ascii_whitespace() || char == ',' =>
        self.advance() |> ignore
      _ => break
    }
  }
}

///|
fn TextScanner::read_ident(self : TextScanner) -> String? {
  self.skip_wsp()
  let start = self.index
  while !self.is_done() {
    match self.peek() {
      Some(char) if char.is_ascii_alphabetic() => self.advance() |> ignore
      _ => break
    }
  }
  if self.index == start {
    None
  } else {
    Some(self.source.unsafe_substring(start~, end=self.index))
  }
}

///|
fn TextScanner::expect_char(
  self : TextScanner,
  expected : Char,
  context : String,
) -> Unit raise SvgError {
  self.skip_wsp()
  match self.advance() {
    Some(char) if char == expected => ()
    _ => raise InvalidTransform(context)
  }
}

///|
fn TextScanner::read_number(self : TextScanner) -> Double? raise SvgError {
  self.read_number_token().map(token => parse_number_token(token))
}

///|
fn TextScanner::read_required_number(
  self : TextScanner,
  context : String,
) -> Double raise SvgError {
  match self.read_number() {
    Some(value) => value
    None => raise ExpectedNumber(context)
  }
}

///|
fn TextScanner::read_number_token(self : TextScanner) -> String? {
  self.skip_comma_wsp()
  let start = self.index
  match self.peek() {
    Some('+') | Some('-') => self.advance() |> ignore
    _ => ()
  }
  let mut has_digit = self.consume_digits()
  match self.peek() {
    Some('.') => {
      self.advance() |> ignore
      has_digit = self.consume_digits() || has_digit
    }
    _ => ()
  }
  if !has_digit {
    self.index = start
    return None
  }
  let exponent_start = self.index
  match self.peek() {
    Some('e') | Some('E') => {
      self.advance() |> ignore
      match self.peek() {
        Some('+') | Some('-') => self.advance() |> ignore
        _ => ()
      }
      if !self.consume_digits() {
        self.index = exponent_start
      }
    }
    _ => ()
  }
  Some(self.source.unsafe_substring(start~, end=self.index))
}

///|
fn TextScanner::consume_digits(self : TextScanner) -> Bool {
  let start = self.index
  while !self.is_done() {
    match self.peek() {
      Some(char) if char.is_ascii_digit() => self.advance() |> ignore
      _ => break
    }
  }
  self.index > start
}

///|
fn parse_number_token(token : String) -> Double raise SvgError {
  @string.parse_double(token) catch {
    _ => raise InvalidNumber(token)
  }
}

///|
fn parse_number_prefix(
  value : String,
  context : String,
) -> Double raise SvgError {
  let scanner = TextScanner::new(value)
  scanner.read_required_number(context)
}
