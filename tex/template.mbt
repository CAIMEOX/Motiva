///|
pub struct TexTemplate {
  priv document_class : String
  priv preamble : String
  priv post_document_commands : String
}

///|
pub fn TexTemplate::new(
  document_class? : String = "\\documentclass[preview]{standalone}",
  preamble? : String = "\\usepackage[english]{babel}\n\\usepackage{amsmath}\n\\usepackage{amssymb}",
  post_document_commands? : String = "",
) -> TexTemplate {
  { document_class, preamble, post_document_commands }
}

///|
pub impl Default for TexTemplate with fn default() -> TexTemplate {
  TexTemplate::new()
}

///|
pub fn TexTemplate::render(
  self : TexTemplate,
  expression : String,
  environment? : String,
) -> String {
  let body = environment.map_or(expression, environment => {
    "\\begin{\{environment}}\n\{expression}\n\\end{\{environment}}"
  })
  "\{self.document_class}\n\{self.preamble}\n\\begin{document}\n\{self.post_document_commands}\n\{body}\n\\end{document}\n"
}
