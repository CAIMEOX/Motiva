///|
async test "SvgLoader caches by path and parse options" {
  @async.with_task_group() <| root => {
    let path = "_build/svg_loader_cache_test.svg"
    root.add_defer(() => @fs.remove(path))
    let source =
      #|<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10">
      #|  <rect width="20" height="10" fill="red" />
      #|</svg>
    @fs.write_file(path, source, create_mode=CreateOrTruncate)
    let loader = SvgLoader::new()
    let first = loader.load(path, center=false)
    guard first.object().node is Group([first_rect]) &&
      first_rect.node is Path(first_path, _) else {
      fail("fixture should contain one rectangular path")
    }
    assert_eq(first_path.commands.length(), 5)
    first_path.line_to(@object.Vec3::new(x=100.0, y=100.0))
    assert_eq(first_path.commands.length(), 6)
    @fs.write_file(path, "<svg", create_mode=CreateOrTruncate)
    let cached = loader.load(path, center=false)
    guard cached.object().node is Group([cached_rect]) &&
      cached_rect.node is Path(cached_path, _) else {
      fail("cached fixture should contain one rectangular path")
    }
    assert_eq(cached_path.commands.length(), 5)
    assert_true(first.object().bounds() is Some(_))
    assert_true(cached.object().bounds() is Some(_))
    let result : Result[@svg.SvgObject, SvgLoadError] = try
      loader.load(path, center=true)
    catch {
      error => Err(error)
    } noraise {
      object => Ok(object)
    }
    match result {
      Err(Parse(_)) => ()
      _ => fail("expected a parse error for a different cache key")
    }
  }
}

///|
async test "SvgLoader can clear cached resources" {
  @async.with_task_group() <| root => {
    let path = "_build/svg_loader_clear_test.svg"
    root.add_defer(() => @fs.remove(path))
    let source =
      #|<svg xmlns="http://www.w3.org/2000/svg">
      #|  <circle r="2" />
      #|</svg>
    @fs.write_file(path, source, create_mode=CreateOrTruncate)
    let loader = SvgLoader::new()
    ignore(loader.load(path))
    loader.clear()
    @fs.write_file(path, "<svg", create_mode=CreateOrTruncate)
    let result : Result[@svg.SvgObject, SvgLoadError] = try
      loader.load(path)
    catch {
      error => Err(error)
    } noraise {
      object => Ok(object)
    }
    match result {
      Err(Parse(_)) => ()
      _ => fail("expected a parse error after clearing the cache")
    }
  }
}
