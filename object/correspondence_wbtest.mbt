///|
test "object correspondence keeps duplicate keys in deterministic buckets" {
  let source = [
    CorrespondencePart::new(FamilyPath::root().child(0), "x"),
    CorrespondencePart::new(FamilyPath::root().child(1), "x"),
    CorrespondencePart::new(FamilyPath::root().child(2), "+"),
  ]
  let target = [
    CorrespondencePart::new(FamilyPath::root().child(0), "x"),
    CorrespondencePart::new(FamilyPath::root().child(1), "="),
  ]
  let correspondence = ObjectCorrespondence::by_key(source, target)
  guard correspondence.buckets() is [bucket] else {
    fail("only the shared x key should produce a matched bucket")
  }
  assert_eq(bucket.source.length(), 2)
  assert_eq(bucket.target.length(), 1)
  guard correspondence.source_only() is [source_only] else {
    fail("plus should remain unmatched")
  }
  guard correspondence.target_only() is [target_only] else {
    fail("equals should remain unmatched")
  }
  assert_eq(source_only.indices(), [2])
  assert_eq(target_only.indices(), [1])
}
