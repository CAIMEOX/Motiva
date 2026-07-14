///|
pub struct FamilyPath {
  priv indices : Array[Int]
} derive(Eq)

///|
pub fn FamilyPath::root() -> FamilyPath {
  { indices: [] }
}

///|
pub fn FamilyPath::child(self : FamilyPath, index : Int) -> FamilyPath {
  let indices = self.indices.copy()
  indices.push(index)
  { indices, }
}

///|
pub fn FamilyPath::indices(self : FamilyPath) -> Array[Int] {
  self.indices.copy()
}
