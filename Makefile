.PHONY: docs docs-serve docs-clean

docs:
	mdbook build

docs-serve:
	mdbook serve --open

docs-clean:
	rm -rf book
