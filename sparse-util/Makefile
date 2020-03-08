all: build test

build:
	gcc src/sparse.c -o sparse -std=c99

test:
	python3 tests/test_sparse.py

clean:
	rm -f sparse
