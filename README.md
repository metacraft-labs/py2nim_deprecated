# py2nim

A Python to Nim transpiler.

* generation of idiomatic Nim code
* automating some of the work involved in porting Python libraries

The project is still under active development and many Python patterns/constructs can't be translated yet.

## Installation

Currently py2nim is mostly useful in development mode, so there are no prebuilt packages yet

You need to setup

* The devel version of Nim. Please clone the [Nim repository](https://github.com/nim-lang/nim/) in a directory placed next to py2nim.
* A working Python environment

Install py2nim with

*
  ```bash
  git clone git@github.com:metacraft-labs/py2nim.git
  cd py2nim
  git submodule update --init --recursive
  ```

*
   ```bash
   cd python-deduckt
   pip install -r requirements.txt
   ```

* Build with

   ```bash
   nim c py2nim.nim
   ```

Now you should have a `py2nim` binary

## Usage

```bash
./py2nim example/fib.py
```

Usually you want to run it on a python module that invokes tests or other code.
Tests are often a good fit, as their execution should invoke most of the useful
code in the translated project. Since many tests may involve the use of mocked
instances and types, it's preferrable to select tests that are closer to the
real-world usage of the code (e.g. integration tests).

Currently there is still no way to combine the results of several different runs,
but this capability will be available soon.

The output is in an `output` directory by default.
You can specify another one with `-o:`

## Limitations

py2nim is in active development and many python constructs cannot be translated yet.
When py2nim encounters code that cannot be translated, it will insert the following markers in the generated code:

* A commented out snippet with the original Python code section
* Optionally, a suggestion or a tip for manual translation
* A warn message in stderr

(currently only the warn message is produced)

py2nim is currently limited to the translation of one package at a time. We assume
that any foreign imports would be either libraries for which there will be internal
mappings or libraries that will be translated separately.

We have tested mostly with versions of Python3, but py2nim seems to work fine with
Python2.7 too.

Also, we still crash on some files, which shouldn't happen. Ideally py2nim should be very fault tolerant and
produce the best code it can ignoring the parts it can't analyze

## Implementation

py2nim infers the types of all Python functions with [our python-deduckt library](https://github.com/metacraft-labs/python-deduckt)
After that it applies further type inference on the AST based on knowledge about Python semantics.
It detects some typical Python patterns and constructs and translates them to idiomatic Nim equivalents.
It also has internal mappings of some of the standard library methods to Nim idioms.
Finally it produces `PNode`-s and reuses the compiler's `renderer.nim` to generate code.

## What kind of transformations is py2nim capable of?

You can find an incomplete list in [transformations.md](transformations.md), docs are still in early stage


## Contributions

You can always ask questions in the issues. If you want to contribute, or you want to discuss a possible addition or use case,
please feel welcome to open a new issue

## License

The MIT License (MIT)

Copyright (c) 2017-2018 Zahary Karadjov, Alexander Ivanov

