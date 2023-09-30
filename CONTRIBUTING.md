Contributing
============

If there is something let me know or open a pull request for it. Try
to keep the implementation generic as in by using parameterized types
via D's templating capabilities.

Only make use of exceptions where it is absolutely necessary, normally
go for an exception-less implementation and have an exception-based
one which re-uses the former.

Lastly, coverage cannot drop in any other piece of code due to the
addition of your code, we must ensure we don't introduce any bugs
into _other peoples'_ code who use this library.

**We want those people to feel comfortable that the library works**
