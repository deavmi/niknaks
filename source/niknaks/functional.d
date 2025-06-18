/**
 * Functional tooling
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module niknaks.functional;

import std.traits : isAssignable, isFunction, isDelegate, ParameterTypeTuple, ReturnType;
import std.functional : toDelegate;

/** 
 * Predicate for testing an input type
 * against a condition and returning either
 * `true` or `false`
 *
 * Params:
 *    T = the input type
 */
template Predicate(T)
{
	/**
	 * Parameterized delegate pointer
	 * taking in `T` and returning
	 * either `true` or `false`
	 */
	alias Predicate = bool delegate(T);
}

/** 
 * Given the symbol of a function or
 * delegate this will return a new
 * `Predicate` of it
 *
 * Params:
 *   func = the symbol of the function
 * or delegate to make a predicate of
 */
template predicateOf(alias func)
if(isFunction!(func) || isDelegate!(func))
{
	static if(!__traits(isSame, ReturnType!(func), bool))
	{
		pragma(msg, "Predicates are required to have a return type of bool");
		static assert(false);
	}

	// Obtain all paramaters
	private alias params = ParameterTypeTuple!(func);

	static if(params.length != 1)
	{
		pragma(msg, "Predicates are required to have an arity of 1");
		static assert(false);
	}

	// Obtain the predicate's input type
	private alias predicateParameterType = params[0];

	// Created predicate delegate
	private Predicate!(predicateParameterType) del;

	/** 
	 * Given the symbol of a function or
	 * delegate this will return a new
	 * `Predicate` of it
	 *
	 * Returns: the predicate
	 */
	Predicate!(predicateParameterType) predicateOf()
	{
		// If it is a function, first make it a delegate
		static if(isFunction!(func))
		{
			del = toDelegate(&func);
		}
		else
		{
			del = func;
		}

		return del;
	}
}

version(unittest)
{
	private bool isEven(int number)
	{
		return number%2==0;
	}
}

/**
 * Uses a `Predicate` which tests
 * an integer input for evenness
 *
 * We create the predicate by
 * passing in the symbol of the
 * function or delegate we wish
 * to use for testing truthiness
 * to a template function
 * `predicateOf!(alias)`
 */
unittest
{
	Predicate!(int) pred = predicateOf!(isEven);

	assert(pred(0) == true);
	assert(pred(1) == false);

	bool delegate(int) isEvenDel = toDelegate(&isEven);
	pred = predicateOf!(isEvenDel);

	assert(pred(0) == true);
	assert(pred(1) == false);
}

/** 
 * Default exception which is thrown
 * when `get()` is called on an
 * `Optional!(T)` which has no
 * value set
 */
public class OptionalException : Exception
{
	/** 
	 * Constructs a new `OptionalException`
	 * with the given message
	 *
	 * Params:
	 *   msg = the error text
	 */
	this(string msg)
	{
		super(msg);
	}
}

/** 
 * Optionals for a given type and 
 * with a customizable exception
 * to be thrown when a value is
 * not present and `get()` is
 * called.
 *
 * Params:
 *    T = the value type
 *    onEmptyGet = the `Throwable`
 * to be called when `get()` is
 * called and no value is present
 */
template Optional(T, onEmptyGet = OptionalException, exceptionArgs...)
if(isAssignable!(Throwable, onEmptyGet) // && 
//    __traits(getVirtualMethods, onEmptyGet, "")[0]
  ) // TODO: Check for this() with arity of 1 and string
{
	/** 
	 * The optional itself
	 */
	public struct Optional
	{
		/** 
		 * The value
		 */
		private T value;

		/** 
		 * Flag for if value
		 * has been set or
		 * not
		 */
		private bool isSet = false;

		/** 
		 * Constructs an optional with
		 * the value already set
		 *
		 * Params:
		 *   value = the value to set
		 */
		this(T value)
		{
			set(value);
		}

		/** 
		 * Sets the optional's value
		 *
		 * Params:
		 *   value = the value to set
		 */
		public void set(T value)
		{
			this.value = value;
			this.isSet = true;
		}

		/** 
		 * Checks if a value is present
		 * or not
		 *
		 * Returns: `true` if present,
		 * otherwise `false`
		 */
		public bool isPresent()
		{
			return isSet;
		}

		/** 
		 * Checks if there is
		 * no value present
		 *
		 * Returns: `true` if
		 * no value is present,
		 * `false` otherwise
		 */
		public bool isEmpty()
		{
			return isPresent() == false;
		}

		/** 
		 * Returns the value of this
		 * optional if it is set. If
		 * not set then an exception
		 * is thrown.
		 *
		 * Returns: the value
		 * Throws:
		 *    Throwable if no value
		 * is present
		 */
		public T get()
		{
			if(!isPresent())
			{
				static if(exceptionArgs.length)
				{
					throw new onEmptyGet(exceptionArgs);
				}
				else
				{
					throw new onEmptyGet("Optional has no value yet get was called");
				}
			}

			return value;
		}

		/** 
		 * Creates an empty optional
		 *
		 * This is the same as doing `Optional!(T)()`
		 * or simply declaring a variable
		 * of the type `Optional!(T)
		 *
		 * Returns: an empty optional
		 */
		public static Optional!(T) empty()
		{
			return Optional!(T)();
		}
	}
}

/**
 * Creating an `Optional!(T)` with no 
 * value present and then trying to
 * get the value, which results in
 * an exception
 */
unittest
{
	struct MyType
	{

	}

	Optional!(MyType) d;
	assert(d.isPresent() == false);
	assert(d.isEmpty());
	
	d = Optional!(MyType)();
	assert(d.isPresent() == false);
	assert(d.isEmpty());

	d = Optional!(MyType).empty();
	assert(d.isPresent() == false);
	assert(d.isEmpty());

	try
	{
		d.get();
		assert(false);
	}
	catch(OptionalException)
	{
		assert(true);
	}
}

/**
 * Creating an `Optional!(T)` with a
 * value present and then trying to
 * get the value, which results in
 * said value being returned
 */
unittest
{
	Optional!(byte) f = Optional!(byte)(1);
	assert(f.isPresent() == true);
	assert(f.isEmpty() == false);

	try
	{
		assert(1 == f.get());
	}
	catch(OptionalException)
	{
		assert(false);
	}
}

unittest
{
	struct Message
	{
		private string b;
		// this(string s)
		// {
		// 	this.b = b;
		// }
	}

	Message m = Message("Hello");
	// Result!(Message, string) m_res = Result!(Message, string)(m);
	Result!(Message, string) m_res = ok!(Message, string)(m);
}

unittest
{
	struct Message
	{
		private string b;
		this(string s)
		{
			this.b = b;
		}
	}

	Message m = Message("Hello");

	// This 
	// In this case we succeed as the should fail as declaring a parameter constructor
	// removed the parameterless one and since our error
	// field will not be set (inside `Result`) it will fail
	// to (at compile time) have its parameter constructor
	// filled with arguments
	static assert(__traits(compiles, error!(string, Message)("hi")));
}

unittest
{
	
}

/** 
 * A result type
 */
@nogc
public struct Result(Okay, Error = string)
if(!__traits(isSame, Okay, Error)) // must be distinct
{
	private union Val
	{
		Okay okay_val;
		Error error_val;
	}
	private Val _v;
	
	private bool _isSucc;
	
	// Prevent intentional bade state
	@disable
	private this();

	public this(Okay okay) @safe
	{
		this._isSucc = true;
		this._v.okay_val = okay;
	}

	public this(Error error) @safe
	{
		this._isSucc = false;
		this._v.error_val = error;
	}

	/** 
	 * Retuns the okay value
	 *
	 * Returns: the value
	 */
	public Okay ok()
	{
		assert(is_okay());
		return this._v.okay_val;
	}

	/** 
	 * Returns the error value
	 *
	 * Returns: the value
	 */
	public Error error()
	{
		assert(is_error());
		return this._v.error_val;
	}

	/** 
	 * Returns the okayness of
	 * this result
	 *
	 * See_Also: `is_okay`
	 * Returns: a boolean
	 */
	public bool opCast(T)() @safe
	if(__traits(isSame, T, bool))
	{
		return is_okay();
	}

	/** 
	 * Check if is okay
	 *
	 * Returns: `true` if
	 * okay, `false` otherwise
	 */
	public bool is_okay() @safe
	{
		return this._isSucc == true;
	}

	/** 
	 * Check if is erroneous
	 *
	 * Returns: `true` if
	 * erroneous, `false`
	 * otherwise
	 */
	public bool is_error() @safe
	{
		return this._isSucc == false;
	}
}

/** 
 * Constructs a new `Result` with the
 * status set to okay and with the
 * provided value.
 *
 * If you don't specify the type
 * of the error value for this
 * then it is assumed to be of
 * type `string`.
 *
 * Params:
 *   okayVal = the okay value
 * Returns: a `Result`
 */
@safe @nogc
public static Result!(OkayType, ErrorType) ok(OkayType, ErrorType = string)(OkayType okayVal)
{
	return Result!(OkayType, ErrorType)(okayVal);
}

/** 
 * Constructs a new `Result` with the
 * status set to error and with the
 * provided value.
 *
 * If you don't specify the type
 * of the okay value for this
 * then it is assumed to be of
 * type `string`.
 *
 * Params:
 *   errorVal = the error value
 * Returns: a `Result`
 */
@safe @nogc
public static Result!(OkayType, ErrorType) error(ErrorType, OkayType = string)(ErrorType errorVal)
{
	return Result!(OkayType, ErrorType)(errorVal);
}

/**
 * Tests the usage of okay
 * result types
 */
unittest
{
	struct Message
	{
		string _m;
		this(string m)
		{
			this._m = m;
		}
	}
	Message m = Message("Hello");

	auto a = ok(m);
	assert(a.ok()._m == "A successful result");

	// Should be Result!(Message, string)
	static assert(__traits(isSame, typeof(a._v.okay_val), Message));
	static assert(__traits(isSame, typeof(a._v.error_val), string));

	// opCast to bool
	assert(cast(bool)a);

	// Validity checking
	assert(a.is_okay());
	assert(!a.is_error());
	
	auto b = ok!(string, Exception)("A successful result");
	assert(b.ok() == "A successful result");

	// Should be Result!(string, Exception)
	static assert(__traits(isSame, typeof(b._v.okay_val), string));
	static assert(__traits(isSame, typeof(b._v.error_val), Exception));
}

/**
 * Tests the usage of error
 * result types
 */
unittest
{
	auto a = error(new Exception("A failed result"));
	assert(cast(Exception)a.error() && (cast(Exception)a.error()).msg == "A failed result");

	// Should be Result!(string, Exception)
	static assert(__traits(isSame, typeof(a._v.okay_val), string));
	static assert(__traits(isSame, typeof(a._v.error_val), Exception));

	// opCast to bool
	assert(!cast(bool)a);

	// Validity checking
	assert(!a.is_okay());
	assert(a.is_error());
	
	auto b = error!(Exception, string)(new Exception("A failed result"));
	assert(cast(Exception)a.error() && (cast(Exception)a.error()).msg == "A failed result");

	// Should be Result!(string, Exception)
	static assert(__traits(isSame, typeof(b._v.okay_val), string));
	static assert(__traits(isSame, typeof(b._v.error_val), Exception));
}