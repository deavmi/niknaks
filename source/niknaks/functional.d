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
	Optional!(int) d;
	assert(d.isPresent() == false);

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

	try
	{
		assert(1 == f.get());
	}
	catch(OptionalException)
	{
		assert(false);
	}
}

@safe @nogc
public struct Result(Okay, Error)
{
	private Okay okay_val;
	private Error error_val;

	private bool isSucc;
	
	@disable
	private this();

	private this(bool isSucc)
	{
		this.isSucc = isSucc;
	}

	public Okay ok()
	{
		return this.okay_val;
	}

	public Error error()
	{
		return this.error_val;
	}

	public bool opCast(T)()
	if(__traits(isSame, T, bool))
	{
		return is_okay();
	}

	public bool is_okay()
	{
		return this.isSucc == true;
	}

	public bool is_error()
	{
		return this.isSucc == false;
	}
}


@safe @nogc
public static Result!(OkayType, ErrorType) ok(OkayType, ErrorType = OkayType)(OkayType okayVal)
{
	Result!(OkayType, ErrorType) result = Result!(OkayType, ErrorType)(true);
	result.okay_val = okayVal;

	return result;
}

@safe @nogc
public static Result!(OkayType, ErrorType) error(ErrorType, OkayType = ErrorType)(ErrorType errorVal)
{
	Result!(OkayType, ErrorType) result = Result!(OkayType, ErrorType)(false);
	result.error_val = errorVal;

	return result;
}

/**
 * Tests the usage of okay
 * result types
 */
unittest
{
	auto a = ok("A successful result");
	assert(a.ok == "A successful result");
	assert(a.error == null);

	// Should be Result!(string, string)
	static assert(__traits(isSame, typeof(a.okay_val), string));
	static assert(__traits(isSame, typeof(a.error_val), string));

	// opCast to bool
	assert(cast(bool)a);

	// Validity checking
	assert(a.is_okay());
	assert(!a.is_error());
	
	auto b = ok!(string, Exception)("A successful result");
	assert(b.ok == "A successful result");
	assert(b.error is null);

	// Should be Result!(string, Exception)
	static assert(__traits(isSame, typeof(b.okay_val), string));
	static assert(__traits(isSame, typeof(b.error_val), Exception));
}

/**
 * Tests the usage of error
 * result types
 */
unittest
{
	auto a = error(new Exception("A failed result"));
	assert(a.ok is null);
	assert(cast(Exception)a.error && (cast(Exception)a.error).msg == "A failed result");

	// Should be Result!(Exception, Exception)
	static assert(__traits(isSame, typeof(a.okay_val), Exception));
	static assert(__traits(isSame, typeof(a.error_val), Exception));

	// opCast to bool
	assert(!cast(bool)a);

	// Validity checking
	assert(!a.is_okay());
	assert(a.is_error());
	
	auto b = error!(Exception, string)(new Exception("A failed result"));
	assert(a.ok is null);
	assert(cast(Exception)a.error && (cast(Exception)a.error).msg == "A failed result");

	// Should be Result!(string, Exception)
	static assert(__traits(isSame, typeof(b.okay_val), string));
	static assert(__traits(isSame, typeof(b.error_val), Exception));
}