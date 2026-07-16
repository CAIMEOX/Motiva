///|
priv struct TextIndexMap {
  source : String
  rendered : String
  byte_offsets : Array[Int]
  owners : Array[Int]
  source_boundaries : Array[Int]
  source_character_count : Int
}

///|
fn prepare_plain_text(
  source : String,
  tab_width : Int,
) -> TextIndexMap raise TextError {
  if tab_width <= 0 {
    raise InvalidTabWidth(tab_width)
  }
  let builder = StringBuilder()
  let owners : Array[Int] = []
  let source_boundaries : Array[Int] = [0]
  let mut source_index = 0
  for char in source {
    if char == '\t' {
      for _ in 0..<tab_width {
        builder.write_char(' ')
        owners.push(source_index)
      }
    } else {
      builder.write_char(char)
      owners.push(source_index)
    }
    source_index = source_index + 1
    source_boundaries.push(owners.length())
  }
  let rendered = builder.to_string()
  {
    source,
    rendered,
    byte_offsets: utf8_byte_offsets(rendered),
    owners,
    source_boundaries,
    source_character_count: source_index,
  }
}

///|
fn prepare_identity_text(source : String) -> TextIndexMap {
  let owners : Array[Int] = []
  let source_boundaries : Array[Int] = [0]
  let mut source_index = 0
  for _ in source {
    owners.push(source_index)
    source_index = source_index + 1
    source_boundaries.push(source_index)
  }
  {
    source,
    rendered: source,
    byte_offsets: utf8_byte_offsets(source),
    owners,
    source_boundaries,
    source_character_count: source_index,
  }
}

///|
fn utf8_byte_offsets(text : String) -> Array[Int] {
  let offsets : Array[Int] = [0]
  let mut offset = 0
  for char in text {
    offset = offset + @utf8.encode(char.to_string()).length()
    offsets.push(offset)
  }
  offsets
}

///|
fn TextIndexMap::span_bytes(
  self : TextIndexMap,
  start : Int,
  end : Int,
) -> (Int, Int) raise TextError {
  if start < 0 || end < start || end > self.source_character_count {
    raise InvalidSpan(start~, end~, character_count=self.source_character_count)
  }
  let rendered_start = self.source_boundaries[start]
  let rendered_end = self.source_boundaries[end]
  (self.byte_offsets[rendered_start], self.byte_offsets[rendered_end])
}

///|
fn TextIndexMap::source_range(
  self : TextIndexMap,
  byte_start : Int,
  byte_end : Int,
) -> TextRange raise TextError {
  let rendered_start = self.rendered_character_boundary(byte_start)
  let rendered_end = self.rendered_character_boundary(byte_end)
  let start = if rendered_start < self.owners.length() {
    self.owners[rendered_start]
  } else {
    self.source_character_count
  }
  let end = if rendered_end > rendered_start {
    self.owners[rendered_end - 1] + 1
  } else {
    start
  }
  { start, end }
}

///|
fn TextIndexMap::rendered_character_boundary(
  self : TextIndexMap,
  byte_offset : Int,
) -> Int raise TextError {
  for index, offset in self.byte_offsets {
    if offset == byte_offset {
      return index
    }
  }
  raise Native(
    status=4,
    message="Pango returned a byte offset outside a UTF-8 character boundary",
  )
}
