# Contributing

- [Adding transforms](#adding-transforms)
- [Generated docs](#generated-docs)
- [Commit style](#commit-style)

## Adding transforms

`tint.lua` defines `__.transforms`, which follows:

- `key`: Name of the transform to use, comes from `tint.transforms`
- `value`: `function` that should return a table of `transforms`. See `:h tint-transforms` for more details on the function implementation.

In order to create a new transform for others to use:

1. Add a new key and value to `tint.transforms` in `tint.lua`
2. Add a new function for your new key in `__.transforms` in `tint.lua`

Throw this in a PR along with a screenshot of your transform.

## Generated Docs

Documentation is generated using [md2vim](https://github.com/FooSoft/md2vim). If you update `DOC.md`, make sure you run `make docs` and commit the changes it creates.

## Commit style

Commits should follow the [conventional commits guidelines](https://www.conventionalcommits.org/en/v1.0.0/)
