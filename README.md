![](branding/banner.png)

Niknaks
=======

![DUB](https://img.shields.io/dub/v/niknaks?color=%23c10000ff%20&style=flat-square) ![DUB](https://img.shields.io/dub/dt/niknaks?style=flat-square) ![DUB](https://img.shields.io/dub/l/niknaks?style=flat-square) [![D](https://github.com/deavmi/niknaks/actions/workflows/d.yml/badge.svg)](https://github.com/deavmi/niknaks/actions/workflows/d.yml) 
[![Coverage Status](https://coveralls.io/repos/github/deavmi/niknaks/badge.svg?branch=master)](https://coveralls.io/github/deavmi/niknaks?branch=master)

#### Helpful _niknaks_ or "things" that you may grasp for now and then

## Usage

To add the package to your project use the following:

```d
dub add niknaks
```

[**Now read the DOCS!**](https://niknaks.dpldocs.info/)

### Modules

Below is a short description of what each module provides, the list
is expected to grow over time.

* `niknaks.functional`
    * Predicates
    * Optionals
    * Result types
* `niknaks.arrays`
    * Unique element generation
    * Prescence checking
* `niknaks.bits`
    * Integral to byte conversions
    * Byte ordering functions
* `niknaks.debugging`
    * **Automagic** dumping of arrays to textual representation
        * Supports arrays-of-arrays-of...
    * Enter-leave (with argument and name printing) for methods
    * An implementation of a jump-buffer with `View`
* `niknaks.containers`
    * Some useful container types
    * Things such as `CacheMap`, `Graph` and `VisitationTree`
    * Also contains a jump-buffer implementation known as `View`
    * A generic pooling mechanism known as `Pool`
* `niknaks.mechanisms`
    * User-defined input prompter, retry mechanisms
* `niknaks.config`
    * Configuration entries and management
* `niknaks.text`
    * Textual manipulation routines
* `niknaks.meta`
    * Template-oriented helper routines

## License

LGPL 3.0

## Contributing

If there is something let me know or open a pull request for it. Try
to keep the implementation generic as in by using parameterized types
via D's templating capabilities.

Only make use of exceptions where it is absolutely necessary, normally
go for an exception-less implementation and have an exception-based
one which re-uses the former.

For more information please see [CONTRIBUTING](CONTRIBUTING.md).
