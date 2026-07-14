///|
test "family path resolves a nested scene object" {
  let scene = @scene.Scene::new()
  let root = scene.object(
    @object.Object::group([
      @object.into_object(@object.Square::new()),
      @object.Object::group([
        @object.into_object(@object.Circle::new()),
        @object.into_object(@object.Rectangle::new()),
      ]),
    ]),
  )
  let nested_circle = scene.resolve_family_path(
    root,
    @object.FamilyPath::root().child(1).child(0),
  )
  guard scene.get(nested_circle) is Some(object) else {
    fail("resolved family member should exist")
  }
  assert_true(object.node is Path(_, _))
  guard scene.children(root) is [_, nested_group] else {
    fail("root should retain its two children")
  }
  guard scene.parent(nested_circle) is Some(parent) else {
    fail("resolved family member should retain its parent")
  }
  assert_eq(parent.value(), nested_group.value())
}

///|
test "family root path resolves to the supplied root" {
  let scene = @scene.Scene::new()
  let root = scene.object(@object.Square::new())
  let resolved = scene.resolve_family_path(root, @object.FamilyPath::root())
  assert_eq(resolved.value(), root.value())
}

///|
test "invalid family path reports a typed scene error" {
  let scene = @scene.Scene::new()
  let root = scene.object(@object.Square::new())
  let result = try
    scene.resolve_family_path(root, @object.FamilyPath::root().child(0))
  catch {
    error => Err(error)
  } noraise {
    id => Ok(id)
  }
  assert_true(result is Err(UnknownFamilyPath(_, _)))
}
