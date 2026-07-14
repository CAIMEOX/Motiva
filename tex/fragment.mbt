///|
pub(all) enum TexFragmentKind {
  Main
  Isolated
} derive(Eq)

///|
pub(all) struct TexFragment {
  tex_string : String
  kind : TexFragmentKind
  path : @object.FamilyPath
  index : Int
} derive(Eq)
