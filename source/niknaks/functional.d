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

// import std.traits : ReturnType, isFunction, Parameters;

// template makeDelegate(alias funcName)
// if(isFunction(funcName))
// {
// 	ReturnType!(funcName) createdDelegate(Parameters!(funcName))
// 	{
// 		return funcName();
// 	}

// 	ReturnType!(funcName) delegate makeDelegate()
// 	{
// 		return createdDelegate;
// 	}
// }

import std.traits : isFunction, ParameterTypeTuple, isFunction;
import std.functional : toDelegate;

template predicateOf(alias func)
if(isFunction!(func) || isDelegate!(func))
{
	// Obtain the predicate's input type
	alias predicateParameterType = ParameterTypeTuple!(func)[0];

	// Created predicate delegate
	Predicate!(predicateParameterType) del;

	Predicate!(predicateParameterType) predicateOf()
	{
		// If it is a function, first make it a delegate
		static if(isFunction!(func))
		{
			del = toDelegate(&func);
		}
		else
		{
			del = &func;
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
 */
unittest
{
	Predicate!(int) pred = predicateOf!(isEven);

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