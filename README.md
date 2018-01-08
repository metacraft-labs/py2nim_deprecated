# py2nim

A Python to Nim compiler. 

* generation of idiomatic Nim code
* automating some of the work involved in porting Python libraries

The project is still under active development and many Python patterns/constructs can't be translated yet.

## Install

Currently py2nim is mostly useful in development mode, so there are no prebuilt packages yet

You need to setup

* the devel version of Nim: you can follow the steps in https://github.com/nim-lang/nim/
* a working Python environment

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

## Command options

```bash
./py2nim fullpath_testfile.py [-o:outputfolder]
```

Usually you want to run it on a python module that invokes tests or other code.
Tests are often a good fit, as their run invokes most of the useful code in the Python project.
If you have a way to provide a run with maximally real-world like usage (eg integration tests),
use that.

Currently there is still no way to combine the results of several different runs, but this ability
should be available soon.

The output is in an `output` directory by default. You can specify another one with `-o:`

## Limitations

py2nim is in active development and many python constructs cannot be translated yet.
When py2nim encounters code that cannot be translated, it will insert the following markers in the generated code:

* A commented out snippet with the original Python code section
* Optionally, a suggestion or a tip for manual translation
* A warn message in stderr

(currently only the warn message is produced)

It is limited to the translation of one package at a time: it assumes that any foreign import-s would be
either of libraries about which it will have internal mappings(in the future, providable by an user) or
libraries that the user will port himself.

We have tested mostly with versions of Python3, but py2nim seems to work fine with Python2.7 too.

## Implementation

py2nim infers types of Python functions with [our python-deduckt library](https://github.com/metacraft-labs/python-deduckt)
After that it applies further type inference on the AST based on knowledge about Python semantics.
It detects some typical Python patterns and constructs and translated them to idiomatic Nim equivalents.
It has also internal mappings of some of the standard library methods to Nim idioms.
Finally it produces `PNode`-s and reuses the compiler's `renderer.nim` to generate code.

## What kind of transformations is py2nim capable of?

You can find an incomplete list in [transformations.md](transformations.md), docs are still in early stage

## License

The MIT License (MIT)

Copyright (c) 2017-2018 Zahary Karadjov, Alexander Ivanov

