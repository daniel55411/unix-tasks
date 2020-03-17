## Sparse util
This util lets create sparse files. This one takes input only from stdin and writes result to file passed in params

## How build
```bash
cd $PROJECT_ROOT/sparse-util
make
```

On this stage binary will be compiled and tested

## Usage
```bash
gzip -cd sparse-file.gz | ./sparse newsparsefile
```

_gzip_ create non-sparse files so it's excellent example
