///|
pub(all) suberror TexError {
  Host(Error)
  CompilerFailed(
    binary~ : String,
    exit_code~ : Int,
    stdout~ : String,
    stderr~ : String
  )
  MissingArtifact(String)
  SvgParse(@svg.SvgError)
  InvalidFontSize(Double)
}

///|
pub struct TexEngine {
  priv latex : String
  priv dvisvgm : String
  priv cache_dir : String
  priv template : TexTemplate
}

///|
pub fn TexEngine::new(
  latex? : String = "latex",
  dvisvgm? : String = "dvisvgm",
  cache_dir? : String = "output/tex",
  template? : TexTemplate = TexTemplate::default(),
) -> TexEngine {
  { latex, dvisvgm, cache_dir, template }
}

///|
pub impl Default for TexEngine with fn default() -> TexEngine {
  TexEngine::new()
}

///|
pub async fn TexEngine::compile_svg(
  self : TexEngine,
  expression : String,
  environment? : String,
  center? : Bool = true,
  height? : Double,
  width? : Double,
) -> @svg.SvgObject raise TexError {
  let document = self.template.render(expression, environment?)
  ensure_directory(self.cache_dir)
  let stem = select_artifact_stem(self.cache_dir, document)
  let tex_path = artifact_path(self.cache_dir, stem, "tex")
  let dvi_path = artifact_path(self.cache_dir, stem, "dvi")
  let svg_path = artifact_path(self.cache_dir, stem, "svg")
  if !tex_path_exists(tex_path) {
    @fs.write_file(tex_path, document, create_mode=CreateOrTruncate) catch {
      error => raise Host(error)
    }
  }
  if !tex_path_exists(dvi_path) {
    let argv = [
      "-interaction=batchmode",
      "-output-format=dvi",
      "-halt-on-error",
      "-output-directory=\{self.cache_dir}",
      tex_path,
    ]
    run_tex_process(self.latex, argv)
    if !tex_path_exists(dvi_path) {
      raise MissingArtifact(dvi_path)
    }
  }
  if !tex_path_exists(svg_path) {
    let argv = [
      "--page=1",
      "--no-fonts",
      "--verbosity=0",
      "--output=\{svg_path}",
      dvi_path,
    ]
    run_tex_process(self.dvisvgm, argv)
    if !tex_path_exists(svg_path) {
      raise MissingArtifact(svg_path)
    }
  }
  let source = @fs.read_file(svg_path).text() catch {
    error => raise Host(error)
  }
  @svg.SvgObject::parse_string(source, center~, height?, width?) catch {
    error => raise SvgParse(error)
  }
}

///|
async fn ensure_directory(path : String) -> Unit raise TexError {
  if !tex_path_exists(path) {
    @fs.mkdir(path, recursive=true) catch {
      error => raise Host(error)
    }
  }
}

///|
async fn select_artifact_stem(
  cache_dir : String,
  document : String,
) -> String raise TexError {
  let base = document.hash().reinterpret_as_uint().to_string(radix=16)
  let mut collision = 0
  let mut stem = base
  while tex_path_exists(artifact_path(cache_dir, stem, "tex")) {
    let tex_path = artifact_path(cache_dir, stem, "tex")
    let cached = @fs.read_file(tex_path).text() catch {
      error => raise Host(error)
    }
    if cached == document {
      return stem
    }
    collision = collision + 1
    stem = "\{base}-\{collision}"
  }
  stem
}

///|
fn artifact_path(
  cache_dir : String,
  stem : String,
  extension : String,
) -> String {
  "\{cache_dir}/\{stem}.\{extension}"
}

///|
async fn run_tex_process(
  binary : String,
  argv : Array[String],
) -> Unit raise TexError {
  let (exit_code, stdout, stderr) = @process.collect_output(binary, argv) catch {
    error => raise Host(error)
  }
  if exit_code != 0 {
    raise CompilerFailed(
      binary~,
      exit_code~,
      stdout=tex_output_text(stdout),
      stderr=tex_output_text(stderr),
    )
  }
}

///|
async fn tex_path_exists(path : String) -> Bool raise TexError {
  @fs.exists(path) catch {
    error => raise Host(error)
  }
}

///|
fn tex_output_text(data : &@io.Data) -> String raise TexError {
  data.text() catch {
    error => raise Host(error)
  }
}
