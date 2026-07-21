# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project for building an
animation engine inspired by Manim.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod` file listing module
  metadata.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

- Prefer `Option::map`, `map_or`, or `map_or_else` over spelling out
  `None => None; Some(x) => Some(...)` by hand.

- When combining two optional values, prefer matching the tuple `(a, b)` instead
  of nested matches.

### Collection operations

- Use `map` when every input produces exactly one output and order/length are
  preserved. Use an array comprehension (`[for x in xs => ...]`) for the same
  shape when pattern binding or an inline `if` makes the transformation clearer.

- Use `filter` when values are only retained or discarded. Use `filter_map`
  when filtering and changing the element type are one operation.

- Use `fold` only for a genuine reduction into one independently computed
  value, such as a number, bounds, lifecycle summary, or interpreter state. The
  callback should return the next accumulator value. Do not copy an `Array`
  accumulator and then `push`/`append` inside `fold`; that hides mutation inside
  a functional-looking operation and often makes the traversal quadratic.

- `Array` has no `flat_map`. For pure flattening, use
  `array.iter().flat_map(...).to_array()`. If flattening also needs stable
  deduplication, correlated output buffers, or other mutable state, use an
  explicit `for` loop with clearly named builders.

- Use `any`, `all`, and `contains` for boolean quantification and membership.
  Do not introduce a mutable boolean sentinel, flip it inside a loop, `break`,
  and then return it when the loop only answers a collection predicate. Use a
  search operation when the matching value or index is needed. An explicit
  mutable boolean remains appropriate when it is genuine state carried across
  parser, interpreter, or state-machine iterations rather than a reduction.

- Use `each` for a simple ordered side effect with no index, accumulator,
  `break`, or `continue`. Use `for` for interpreters, mutable builders, early
  control flow, indexed traversal, and algorithms carrying correlated state.
  Mutation is not forbidden; it should be visible in the construct that owns it.

- Methods that mutate internal reference fields, such as pushing into an
  `Array`, should return `Unit`. Return `Self` only for functions that are
  conceptually pure value builders.

- For type defaults, implement the standard `Default` trait instead of adding a
  hand-written `pub fn Type::default()`.

- Do not use `fail` for library/domain errors. `fail` raises an unstructured
  `Failure` and loses the error type. Define a specific `suberror`, raise its
  constructors, and annotate public APIs with the precise error type (for
  example, `fn f(...) -> T raise MyError`). `fail` is acceptable for test
  assertions.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. For snapshot tests that record
  structured debugging output, derive `Debug` and use `debug_inspect`, rather
  than deriving `Show` for debugging. For solid, well-defined results (e.g.
  scientific computations), prefer assertion tests. You can use
  `moon coverage analyze > uncovered.log` to see which parts of your code are
  not covered by tests.
