///|
fn matching_rebuild(patch : FramePatch, id : ObjectId) -> @object.Object? {
  for op in patch.ops {
    match op {
      Rebuild(current, object) => if current == id { return Some(object) }
      _ => ()
    }
  }
  None
}

///|
test "transform matching splits one source part across a target bucket" {
  let scene = Scene::new()
  let source_root = scene.add(
    @object.Object::group([
      @object.into_object(@object.Square::new(side_length=1.0)),
    ]),
  )
  let target_root = scene.object(
    @object.Object::group([
      @object.into_object(@object.Circle::new(radius=0.3)).with_transform(
        @object.Transform::translate(@object.Vec3::new(x=-1.0, y=0.0)),
      ),
      @object.into_object(@object.Circle::new(radius=0.3)),
      @object.into_object(@object.Circle::new(radius=0.3)).with_transform(
        @object.Transform::translate(@object.Vec3::new(x=1.0, y=0.0)),
      ),
    ]),
  )
  guard scene.children(source_root) is [source_part] else {
    fail("source should expose its only part")
  }
  let correspondence = @object.ObjectCorrespondence::by_key(
    [
      @object.CorrespondencePart::new(
        @object.FamilyPath::root().child(0),
        "shape",
      ),
    ],
    [
      @object.CorrespondencePart::new(
        @object.FamilyPath::root().child(0),
        "shape",
      ),
      @object.CorrespondencePart::new(
        @object.FamilyPath::root().child(1),
        "shape",
      ),
      @object.CorrespondencePart::new(
        @object.FamilyPath::root().child(2),
        "shape",
      ),
    ],
  )
  let active = ActiveAnimation::compile(
    scene,
    scene.transform_matching(
      source_root,
      target_root,
      correspondence,
      run_time=2.0,
    ),
  )
  guard matching_rebuild(active.begin_patch(), source_part) is Some(working) &&
    working.node is Group(children) else {
    fail("matching begin should split the source into a working group")
  }
  assert_eq(children.length(), 3)
  scene.apply_frame_patch(active.begin_patch())
  scene.apply_frame_patch(active.finish_patch())
  assert_true(!scene.is_visible(source_root))
  assert_true(scene.is_visible(target_root))
}
