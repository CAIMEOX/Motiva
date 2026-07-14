///|
priv struct PreparedMathSource {
  expression : String
  parts : Array[TexPart]
}

///|
priv struct TexPart {
  source : String
  id : String
  kind : TexFragmentKind
}

///|
fn prepare_math_parts(tex_strings : Array[String]) -> Array[String] {
  let parts : Array[String] = []
  for tex_string in tex_strings {
    for part in split_double_braces(tex_string) {
      if part.length() > 0 {
        parts.push(part)
      }
    }
  }
  parts
}

///|
fn split_double_braces(tex_string : String) -> Array[String] {
  let segments : Array[String] = []
  let mut current = StringBuilder::new(size_hint=tex_string.length())
  let mut index = 0
  let mut inside_group = false
  let mut inner_depth = 0
  let mut previous : Char? = None
  while index < tex_string.length() {
    guard tex_string.get_char(index) is Some(char) else { break }
    let next_index = index + char.utf16_len()
    let next = tex_string.get_char(next_index)
    if char == '\\' &&
      (next is Some('\\') || next is Some('{') || next is Some('}')) {
      current.write_char(char)
      guard next is Some(next_char) else { break }
      current.write_char(next_char)
      index = next_index + next_char.utf16_len()
      previous = Some(next_char)
      continue
    }
    if !inside_group &&
      char == '{' &&
      next is Some('{') &&
      (index == 0 || previous.map_or(false, Char::is_ascii_whitespace)) {
      segments.push(current.to_string())
      current = StringBuilder::new()
      inside_group = true
      inner_depth = 0
      index = next_index + 1
      previous = Some('{')
      continue
    }
    if inside_group && char == '}' && inner_depth == 0 && next is Some('}') {
      segments.push(current.to_string())
      current = StringBuilder::new()
      inside_group = false
      index = next_index + 1
      previous = Some('}')
      continue
    }
    if inside_group && char == '{' {
      inner_depth = inner_depth + 1
    } else if inside_group && char == '}' && inner_depth > 0 {
      inner_depth = inner_depth - 1
    }
    current.write_char(char)
    index = next_index
    previous = Some(char)
  }
  segments.push(current.to_string())
  segments
}

///|
fn prepare_math_source(
  tex_strings : Array[String],
  arg_separator : String,
  substrings_to_isolate? : Array[String] = [],
) -> PreparedMathSource {
  let sources = prepare_math_parts(tex_strings)
  let sources = if sources.length() == 0 { ["\\quad"] } else { sources }
  let parts : Array[TexPart] = []
  let rendered : Array[String] = []
  let mut substring_index = 0
  for index in 0..<sources.length() {
    let source = sources[index]
    let id = "motiva-main-\{index}"
    parts.push({ source, id, kind: Main })
    let (processed, next_substring_index) = isolate_substrings(
      source, substrings_to_isolate, substring_index, parts,
    )
    substring_index = next_substring_index
    let separator = if index + 1 < sources.length() {
      arg_separator
    } else {
      ""
    }
    rendered.push(
      "\\special{dvisvgm:raw <g id='\{id}'>}\{processed}\{separator}\\special{dvisvgm:raw </g>}",
    )
  }
  { expression: rendered.join(""), parts }
}

///|
fn isolate_substrings(
  source : String,
  substrings : Array[String],
  first_index : Int,
  parts : Array[TexPart],
) -> (String, Int) {
  let rendered = StringBuilder::new(size_hint=source.length())
  let mut remaining = source
  let mut index = first_index
  while remaining.length() > 0 {
    match first_isolated_substring(remaining, substrings) {
      None => {
        rendered.write_string(remaining)
        remaining = ""
      }
      Some((offset, matched)) => {
        if offset > 0 {
          rendered.write_string(remaining.unsafe_substring(start=0, end=offset))
        }
        let id = "motiva-sub-\{index}"
        parts.push({ source: matched, id, kind: Isolated })
        rendered.write_string("\\special{dvisvgm:raw <g id='\{id}'>}")
        rendered.write_string(matched)
        rendered.write_string("\\special{dvisvgm:raw </g>}")
        let next = offset + matched.length()
        remaining = remaining.unsafe_substring(
          start=next,
          end=remaining.length(),
        )
        index = index + 1
      }
    }
  }
  (rendered.to_string(), index)
}

///|
fn first_isolated_substring(
  source : String,
  substrings : Array[String],
) -> (Int, String)? {
  let mut first : (Int, String)? = None
  for substring in substrings {
    if substring.length() > 0 {
      match source.find(substring) {
        None => ()
        Some(offset) =>
          match first {
            None => first = Some((offset, substring))
            Some((current_offset, current)) if offset < current_offset ||
              (
                offset == current_offset &&
                substring.length() > current.length()
              ) => first = Some((offset, substring))
            _ => ()
          }
      }
    }
  }
  first
}
