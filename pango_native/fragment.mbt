///|
pub(all) struct TextFragment {
  source : String
  range : TextRange
  clusters : Array[TextCluster]
  paths : Array[@object.FamilyPath]
} derive(Debug)

///|
pub fn RenderedText::character_count(self : RenderedText) -> Int {
  self.character_count
}

///|
pub fn RenderedText::fragment(
  self : RenderedText,
  start : Int,
  end : Int,
) -> TextFragment raise TextError {
  let character_count = self.character_count()
  if start < 0 || end < start || end > character_count {
    raise InvalidSpan(start~, end~, character_count~)
  }
  let clusters = self.clusters
    .filter(cluster => cluster.range.start < end && cluster.range.end > start)
    .map(copy_text_cluster)
  {
    source: character_slice(self.source, start, end),
    range: { start, end },
    clusters,
    paths: clusters.iter().flat_map(cluster => cluster.paths.iter()).to_array(),
  }
}

///|
pub fn RenderedText::fragments_by_text(
  self : RenderedText,
  pattern : String,
) -> Array[TextFragment] raise TextError {
  [
    for range in find_character_ranges(self.source, pattern) => {
      self.fragment(range.start, range.end)
    }
  ]
}

///|
pub fn RenderedText::characters(self : RenderedText) -> Array[TextFragment] {
  let grouped : Array[Array[TextCluster]] = [
    for _ in 0..<self.character_count => []
  ]
  for cluster in self.clusters {
    let start = Int::max(0, cluster.range.start)
    let end = Int::min(self.character_count, cluster.range.end)
    for index in start..<end {
      grouped[index].push(copy_text_cluster(cluster))
    }
  }
  let characters = string_characters(self.source)
  [
    for index, character in characters => {
      let clusters = grouped[index]
      {
        source: character.to_string(),
        range: { start: index, end: index + 1 },
        clusters,
        paths: clusters
        .iter()
        .flat_map(cluster => cluster.paths.iter())
        .to_array(),
      }
    }
  ]
}

///|
pub fn TextSpec::with_style_by_text(
  self : TextSpec,
  pattern : String,
  font_family? : String,
  font_size? : Double,
  slant? : FontSlant,
  weight? : FontWeight,
  stretch? : FontStretch,
  color? : @object.Rgba,
  background? : @object.Rgba,
  underline? : TextUnderline,
  underline_color? : @object.Rgba,
  overline? : Bool,
  overline_color? : @object.Rgba,
  strikethrough? : Bool,
  strikethrough_color? : @object.Rgba,
  rise? : Double,
  letter_spacing? : Double,
  font_features? : String,
  language? : String,
) -> TextSpec raise TextError {
  let spans = self.spans.copy()
  for range in find_character_ranges(self.text, pattern) {
    spans.push(
      TextSpan::new(
        range.start,
        range.end,
        font_family?,
        font_size?,
        slant?,
        weight?,
        stretch?,
        color?,
        background?,
        underline?,
        underline_color?,
        overline?,
        overline_color?,
        strikethrough?,
        strikethrough_color?,
        rise?,
        letter_spacing?,
        font_features?,
        language?,
      ),
    )
  }
  { ..self, spans, }
}

///|
pub fn TextSpec::with_color_by_text(
  self : TextSpec,
  pattern : String,
  color : @object.Rgba,
) -> TextSpec raise TextError {
  self.with_style_by_text(pattern, color~)
}

///|
pub fn TextSpec::with_font_by_text(
  self : TextSpec,
  pattern : String,
  family : String,
) -> TextSpec raise TextError {
  self.with_style_by_text(pattern, font_family=family)
}

///|
pub fn TextSpec::with_slant_by_text(
  self : TextSpec,
  pattern : String,
  slant : FontSlant,
) -> TextSpec raise TextError {
  self.with_style_by_text(pattern, slant~)
}

///|
pub fn TextSpec::with_weight_by_text(
  self : TextSpec,
  pattern : String,
  weight : FontWeight,
) -> TextSpec raise TextError {
  self.with_style_by_text(pattern, weight~)
}

///|
fn find_character_ranges(
  source : String,
  pattern : String,
) -> Array[TextRange] raise TextError {
  let source_chars = string_characters(source)
  let pattern_chars = string_characters(pattern)
  if pattern_chars.is_empty() {
    raise EmptyPattern
  }
  let ranges : Array[TextRange] = []
  let mut index = 0
  while index + pattern_chars.length() <= source_chars.length() {
    let matches = source_chars[index:index + pattern_chars.length()]
      .iter()
      .zip(pattern_chars.iter())
      .all(pair => pair.0 == pair.1)
    if matches {
      ranges.push({ start: index, end: index + pattern_chars.length() })
      index = index + pattern_chars.length()
    } else {
      index = index + 1
    }
  }
  ranges
}

///|
fn string_characters(text : String) -> Array[Char] {
  let characters : Array[Char] = []
  for character in text {
    characters.push(character)
  }
  characters
}

///|
fn character_slice(source : String, start : Int, end : Int) -> String {
  let builder = StringBuilder()
  let mut index = 0
  for character in source {
    if index >= start && index < end {
      builder.write_char(character)
    }
    index = index + 1
  }
  builder.to_string()
}
