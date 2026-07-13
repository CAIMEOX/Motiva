///|
pub(all) suberror SvgLoadError {
  Host(Error)
  Parse(@svg.SvgError)
}

///|
struct SvgCacheKey {
  path : String
  center : Bool
  height : Double?
  width : Double?
} derive(Eq, Hash)

///|
pub struct SvgLoader {
  priv cache : Map[SvgCacheKey, @svg.SvgObject]
}

///|
pub fn SvgLoader::new() -> SvgLoader {
  { cache: {} }
}

///|
pub impl Default for SvgLoader with fn default() -> SvgLoader {
  SvgLoader::new()
}

///|
pub async fn SvgLoader::load(
  self : SvgLoader,
  path : String,
  center? : Bool = true,
  height? : Double,
  width? : Double,
) -> @svg.SvgObject raise SvgLoadError {
  let key = { path, center, height, width }
  match self.cache.get(key) {
    Some(object) => object.copy()
    None => {
      let source = @fs.read_file(path).text() catch {
        error => raise Host(error)
      }
      let object = @svg.SvgObject::parse_string(
        source,
        center~,
        height?,
        width?,
      ) catch {
        error => raise Parse(error)
      }
      self.cache[key] = object.copy()
      object
    }
  }
}

///|
pub fn SvgLoader::clear(self : SvgLoader) -> Unit {
  self.cache.clear()
}
