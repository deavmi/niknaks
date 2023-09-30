Contributing
============

If there is something let me know or open a pull request for it. Try
to keep the implementation generic as in by using parameterized types
via D's templating capabilities.

Only make use of exceptions where it is absolutely necessary, normally
go for an exception-less implementation and have an exception-based
one which re-uses the former.