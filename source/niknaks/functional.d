/**
 * Functional tooling
 */
module niknaks.functional;

import std.traits : isAssignable;

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

import std.traits : isFunction, isDelegate, ParameterTypeTuple, isFunction, ReturnType;
import std.functional : toDelegate;

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
	alias params = ParameterTypeTuple!(func);

	static if(params.length != 1)
	{
		pragma(msg, "Predicates are required to have an arity of 1");
		static assert(false);
	}

	// Obtain the predicate's input type
	alias predicateParameterType = params[0];

	// Created predicate delegate
	private Predicate!(predicateParameterType) del;

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