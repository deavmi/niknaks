/** 
 * Configuration management
 *
 * Configuration entries and
 * a registry in which to
 * manage a set of them
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module niknaks.config;

import std.string : format;

version(unittest)
{
    import std.stdio : writeln;
}

/** 
 * A union which expands to
 * the byte-width of its
 * biggest member, allowing
 * us to have space enough
 * for any one exclusive member
 * at a time
 *
 * See_Also: ConfigEntry
 */
private union ConfigValue
{
    string text;
    size_t integer;
    bool flag;
    string[] textArray;
}

/** 
 * The type of the entry
 */
public enum ConfigType
{
    /** 
     * A string
     */
    TEXT,

    /** 
     * An integer
     */
    NUMERIC,

    /** 
     * A boolean
     */
    FLAG,

    /** 
     * A string array
     */
    ARRAY
}

/** 
 * An exception thrown when you misuse
 * a configuration entry
 */
public final class ConfigException : Exception
{
    private this(string msg)
    {
        super(msg);
    }
}

/** 
 * A configuration entry which
 * acts as a typed union and
 * supports certain fixed types
 */
public struct ConfigEntry
{
    private ConfigValue value;
    private ConfigType type;

    /** 
     * A flag which is used to
     * know if a value has been
     * set at all. This helps
     * with the fact that 
     * an entry can be constructed
     * without having a value set
     */
    private bool isSet = false;

    /** 
     * Ensures a value is set
     */
    private void ensureSet()
    {
        if(!this.isSet)
        {
            throw new ConfigException("This config entry has not yet been set");
        }
    }

    /**
     * Marks this entry as having
     * a value set
     */
    private void set()
    {
        this.isSet = true;
    }

    // TODO: Must have an unset flag
    // @disable
    // private this();
    import std.traits : isIntegral;

    this(EntryType)(EntryType value)
    if
    (
        __traits(isSame, EntryType, string[]) ||
        __traits(isSame, EntryType, string) ||
        isIntegral!(EntryType) ||
        __traits(isSame, EntryType, bool)
    )
    {
        ConfigValue _v;
        ConfigType _t;
        static if(__traits(isSame, EntryType, string[]))
        {
            _v.textArray = value;
            _t = ConfigType.ARRAY;
        }
        else static if(__traits(isSame, EntryType, string))
        {
            _v.text = value;
            _t = ConfigType.TEXT;
        }
        else static if(isIntegral!(EntryType))
        {
            _v.integer = cast(size_t)value;
            _t = ConfigType.NUMERIC;
        }
        else static if(__traits(isSame, EntryType, bool))
        {
            _v.flag = value;
            _t = ConfigType.FLAG;
        }

        this(_v, _t);
    }

    /** 
     * Constructs a new `ConfigEntry`
     * with the given value and type
     *
     * Params:
     *   value = the value itself
     *   type = the value's type
     */
    private this(ConfigValue value, ConfigType type)
    {
        this.value = value;
        this.type = type;

        set();
    }

    /** 
     * Creates a new configuration entry
     * containing text
     *
     * Params:
     *   text = the text
     * Returns: a `ConfigEntry`
     */
    public static ConfigEntry ofText(string text)
    {
        return ConfigEntry(text);
    }

    /** 
     * Creates a new configuration entry
     * containing an integer
     *
     * Params:
     *   i = the integer
     * Returns: a `ConfigEntry`
     */
    public static ConfigEntry ofNumeric(size_t i)
    {
        return ConfigEntry(i);
    }

    /** 
     * Creates a new configuration entry
     * containing a flag
     *
     * Params:
     *   flag = the flag
     * Returns: a `ConfigEntry`
     */
    public static ConfigEntry ofFlag(bool flag)
    {
        return ConfigEntry(flag);
    }

    /** 
     * Creates a new configuration entry
     * containing a textual array
     *
     * Params:
     *   array = the textual array
     * Returns: a `ConfigEntry`
     */
    public static ConfigEntry ofArray(string[] array)
    {
        return ConfigEntry(array);
    }

    /** 
     * Returns the type of the
     * entry's value
     *
     * Returns: a `ConfigType`
     */
    public ConfigType getType()
    {
        return this.type;
    }

    /** 
     * Ensures the requested type
     * matches the current type
     * set
     *
     * Params:
     *   requested = the requested
     * type
     * Returns: `true` if the types
     * are the same, `false` otherwise
     */
    private bool ensureTypeMatch0(ConfigType requested)
    {
        return getType() == requested;
    }

    /** 
     * A version of the type
     * matcher but which throws
     * an exception on type mismatch
     *
     * See_Also: `ensureTypeMatch0(ConfigType)`
     */
    private void ensureTypeMatch(ConfigType requested)
    {
        if(!ensureTypeMatch0(requested))
        {
            throw new ConfigException(format("The entry is not of type '%s'", requested));
        }
    }

    /** 
     * Obtains the numeric value
     * of this entry
     *
     * Returns: an integer
     * Throws: ConfigException if
     * the type of the value in this
     * entry is not numeric
     */
    public size_t numeric()
    {
        ensureSet;
        ensureTypeMatch(ConfigType.NUMERIC);
        return this.value.integer;
    }

    /** 
     * Obtains the textual array
     * value of this entry
     *
     * Returns: a `string[]`
     * Throws: ConfigException if
     * the type of the value in this
     * entry is not a textual array
     */
    public string[] array()
    {
        ensureSet;
        ensureTypeMatch(ConfigType. ARRAY);
        return this.value.textArray;
    }

    /** 
     * See_Also: `array()`
     */
    public string[] opSlice()
    {
        return array();
    }

    /** 
     * Obtains the flag value
     * of this entry
     *
     * Returns: a `string[]`
     * Throws: ConfigException if
     * the type of the value in this
     * entry is not a flag
     */
    public bool flag()
    {
        ensureSet;
        ensureTypeMatch(ConfigType.FLAG);
        return this.value.flag;
    }

    /** 
     * See_Also: `flag()`
     */
    public bool isTrue()
    {
        return flag() == true;
    }

    /** 
     * See_Also: `flag()`
     */
    public bool isFalse()
    {
        return flag() == false;
    }

    /** 
     * Obtains the text value
     * of this entry
     *
     * Returns: a string
     * Throws: ConfigException if
     * the type of the value in this
     * entry is not a string
     */
    public string text()
    {
        ensureSet;
        ensureTypeMatch(ConfigType.TEXT);
        return this.value.text;
    }

    /** 
     * Obtains the value of this
     * configuration entry dependant
     * on the requested casting type
     * and matching that to the supported
     * types of the configuration entry
     *
     * Returns: a value of type `T`
     */
    public T opCast(T)()
    {
        static if(__traits(isSame, T, bool))
        {
            return flag();
        }
        else static if(__traits(isSame, T, string))
        {
            return text();
        }
        else static if(isIntegral!(T))
        {
            return cast(T)numeric();
        }
        else static if(__traits(isSame, T, string[]))
        {
            return array();
        }
        else
        {
            pragma(msg, "ConfigEntry opCast(): Cannot cast to a type '", T, "'");
            static assert(false);
        }
    }
}

/**
 * Tests out using the configuration
 * entry and its various operator
 * overloads
 */
unittest
{
    ConfigEntry entry = ConfigEntry.ofArray(["hello", "world"]);
    assert(entry[] == ["hello", "world"]);

    entry = ConfigEntry.ofNumeric(1);
    assert(entry.numeric() == 1);

    entry = ConfigEntry.ofText("hello");
    assert(cast(string)entry == "hello");

    entry = ConfigEntry.ofFlag(true);
    assert(entry);
}

/** 
 * Tests out the erroneous usage of a
 * configuration entry
 */
unittest
{
    ConfigEntry entry = ConfigEntry.ofText("hello");

    try
    {
        entry[];
        assert(false);
    }
    catch(ConfigException e)
    {
        
    }
}

/** 
 * Tests out the erroneous usage of a
 * configuration entry
 */
unittest
{
    ConfigEntry entry;

    try
    {
        entry[];
        assert(false);
    }
    catch(ConfigException e)
    {
        
    }
}

/** 
 * An entry derived from
 * the `Registry` containing
 * the name and the configuration
 * entry itself
 */
public struct RegistryEntry
{
    private string name;
    private ConfigEntry val;

    /** 
     * Constructs a new `RegistryEntry`
     * with the given name and configuration
     * entry
     *
     * Params:
     *   name = the name
     *   entry = the entry itself
     */
    this(string name, ConfigEntry entry)
    {
        this.name = name;
        this.val = entry;
    }

    /** 
     * Constructs a new `RegistryEntry`
     * with the given name and configuration
     * entry
     *
     * Params:
     *   name = the name
     *   entry = the entry itself
     */
    this(T)(string name, T entry)
    {
        this.name = name;
        this.val = ConfigEntry(entryVal);
    }

    /** 
     * Obtains the entry's name
     *
     * Returns: the name
     */
    public string getName()
    {
        return this.name;
    }

    /** 
     * Obtains the entry itself
     *
     * Returns: a `ConfigEntry`
     */
    public ConfigEntry getEntry()
    {
        return this.val;
    }

    /** 
     * Returns the configugration
     * entry's type
     *
     * See_Also: `ConfigEntry.getType()`
     * Returns: a `ConfigType`
     */
    public ConfigType getType()
    {
        return getEntry().getType();
    }
}

/** 
 * An exception thrown when something
 * goes wrong with your usage of the
 * `Registry`
 */
public final class RegistryException : Exception
{
    private this(string msg)
    {
        super(msg);
    }
}

/** 
 * A registry for managing
 * multiple mappings of
 * string-based names to
 * configuration entries
 */
public struct Registry
{
    private ConfigEntry[string] entries;
    private bool allowOverwriteEntry;

    /** 
     * Creates a new `Registry`
     * and sets the overwriting policy
     *
     * Params:
     *   allowOverwritingOfEntries = `true`
     * if you want to allow overwriting of
     * previously added entries, otherwise
     * `false`
     */
    this(bool allowOverwritingOfEntries)
    {
        setAllowOverwrite(allowOverwritingOfEntries);
    }
    
    /** 
     * Checks if an entry is present
     *
     * Params:
     *   name = the name
     * Returns: `true` if present,
     * otherwise `false`
     */
    public bool hasEntry(string name)
    {
        return getEntry0(name) !is null;
    }

    /** 
     * Ontains a pointer to the configuration
     * entry at the given key.
     *
     * Params:
     *   name = the key
     * Returns: a `ConfigEntry*` if found,
     * otherwise `null`
     */
    private ConfigEntry* getEntry0(string name)
    {
        ConfigEntry* potEntry = name in this.entries;
        return potEntry;
    }

    /** 
     * Obtains a pointer to the configuration
     * entry at the given key. Allowing you
     * to swap out its contents directly if
     * you want to.
     *
     * Params:
     *   name = the key
     * Returns: a `ConfigEntry*` if found,
     * otherwise `null`
     */
    public ConfigEntry* opBinaryRight(string op)(string name)
    if(op == "in")
    {
        return getEntry0(name);
    }

    /** 
     * Obtain a configuration entry
     * at the given key
     *
     * Params:
     *   name = the key
     *   entry = the found entry
     * (if any)
     * Returns: `true` if found,
     * otherwise `false` 
     */
    public bool getEntry_nothrow(string name, ref ConfigEntry entry)
    {
        ConfigEntry* potEntry = getEntry0(name);
        if(potEntry is null)
        {
            return false;
        }

        entry = *potEntry;
        return true;
    }

    /** 
     * Obtain a configuration entry
     * at the given key
     *
     * Params:
     *   name = the key
     * Returns: a configuration entry
     * Throws: RegistryException if
     * there is no entry at that key
     */
    public ConfigEntry opIndex(string name)
    {
        ConfigEntry entry;
        if(!getEntry_nothrow(name, entry))
        {
            throw new RegistryException(format("Cannot find an entry by the name of '%s'", name));
        }

        return entry;
    }

    /** 
     * Set whether or not the overwriting
     * of an entry should be allowed
     *
     * Params:
     *   flag = `true` if to allow, `false`
     * if to deny
     */
    public void setAllowOverwrite(bool flag)
    {
        this.allowOverwriteEntry = flag;
    }

    /** 
     * Adds a new configuration entry at the
     * given key and allows you to choose
     * certain behaviors based on the
     * existence or non-existence of
     * an entry at the same key.
     *
     * Params:
     *   name = the name of the entry
     *   entry = the entry itself
     *   allowOverWriteNow = if `true`
     * then if an entry exists already
     * at that key it will be overwritten,
     * otherwise an exception will be thrown
     *   allowSetOnCreation = if there is
     * no entry at the given key then,
     * if `true`, an entry will be created,
     * otherwise an exception will be thrown
     */
    private void newEntry(string name, ConfigEntry entry, bool allowOverWriteNow, bool allowSetOnCreation)
    {
        // Obtain the address of the value that occupies the value
        // the key in the map
        ConfigEntry* entryExist = getEntry0(name);

        // If something is present but overwiritng is disabled
        if((entryExist !is null) && !allowOverWriteNow)
        {
            throw new RegistryException(format("An entry already exists at '%s' and overwriting is not allowed", name));
        }
        // If something is present and overwiring is enabled
        else if(entryExist !is null)
        {
            // Now simply update the data in-place
            *entryExist = entry;
        }
        // If nothing is present but setting-on-creation is enabled
        else if(allowSetOnCreation)
        {
            // Then create the entry
            this.entries[name] = entry;
        }
        // If nothing is present BUT setting-on-creation was NOT allowed
        else
        {
            throw new RegistryException(format("Cannot set-on-creation for entry '%s' as it is not allowed", name));
        }
    }

    /** 
     * Creates a new entry and adds it
     *
     * An exception is thrown if an entry
     * at that key exists and the policy
     * for overwriting is to deny
     *
     * Params:
     *   name = the key
     *   entry = the configuration entry
     */
    public void newEntry(string name, ConfigEntry entry)
    {
        newEntry(name, entry, this.allowOverwriteEntry, true);
    }

    /** 
     * See_Also: `newEntry(name, ConfigEntry)` 
     */
    public void newEntry(string name, int numeric)
    {
        newEntry(name, ConfigEntry.ofNumeric(numeric));
    }

    /** 
     * See_Also: `newEntry(name, ConfigEntry)` 
     */
    public void newEntry(string name, string text)
    {
        newEntry(name, ConfigEntry.ofText(text));
    }

    /** 
     * See_Also: `newEntry(name, ConfigEntry)` 
     */
    public void newEntry(string name, bool flag)
    {
        newEntry(name, ConfigEntry.ofFlag(flag));
    }

    /** 
     * See_Also: `newEntry(name, ConfigEntry)` 
     */
    public void newEntry(string name, string[] array)
    {
        newEntry(name, ConfigEntry.ofArray(array));
    }

    /** 
     * Sets the entry at the given name
     * to the provided entry
     *
     * This will throw an exception if
     * the entry trying to be set does
     * not yet exist.
     *
     * Overwriting will only be allowed
     * if the policy allows it.
     *
     * Params:
     *   name = the key
     *   entry = the configuration
     * entry
     */
    public void setEntry(string name, ConfigEntry entry)
    {
        newEntry(name, entry, this.allowOverwriteEntry, false);
    }

    /** 
     * Assigns the provided configuration
     * entry to the provided name
     *
     * Take note that using this method
     * will create the entry if it does
     * not yet exist.
     *
     * It will also ALWAYS allow overwriting.
     *
     * Params:
     *   entry = the entry to add
     *   name = the name at which to
     * add the entry
     */
    public void opIndexAssign(ConfigEntry entry, string name)
    {
        newEntry(name, entry, true, true);
    }

    /** 
     * See_Also: `opIndexAssign(ConfigEntry, string)`
     */
    public void opIndexAssign(size_t numeric, string name)
    {
        opIndexAssign(ConfigEntry.ofNumeric(numeric), name);
    }

    /** 
     * See_Also: `opIndexAssign(ConfigEntry, string)`
     */
    public void opIndexAssign(string entry, string name)
    {
        opIndexAssign(ConfigEntry.ofText(entry), name);
    }

    /** 
     * See_Also: `opIndexAssign(ConfigEntry, string)`
     */
    public void opIndexAssign(bool flag, string name)
    {
        opIndexAssign(ConfigEntry.ofFlag(flag), name);
    }

    /** 
     * See_Also: `opIndexAssign(ConfigEntry, string)`
     */
    public void opIndexAssign(string[] array, string name)
    {
        opIndexAssign(ConfigEntry.ofArray(array), name);
    }

    /** 
     * Returns all the entries in the
     * registry as a mapping of their
     * name to their configuration entry
     *
     * See_Also: RegistryEntry
     * Returns: an array of registry
     * entries
     */
    public RegistryEntry[] opSlice()
    {
        RegistryEntry[] entrieS;
        foreach(string entryName; this.entries.keys())
        {
            entrieS ~= RegistryEntry(entryName, this.entries[entryName]);
        }

        return entrieS;
    }
}

/**
 * Tests out the working with the
 * registry in order to manage
 * a set of named configuration
 * entries
 */
unittest
{
    Registry reg = Registry(false);

    // Add an entry
    reg.newEntry("name", "Tristan");

    // Check it exists
    assert(reg.hasEntry("name"));

    // Adding it again should fail
    try
    {
        reg.newEntry("name", "Tristan2");
        assert(false);
    }
    catch(RegistryException e)
    {

    }

    // Check that the entry still has the right value
    assert(cast(string)reg["name"] == "Tristan");

    // // Add a new entry and test its prescence
    reg["age"] = 24;
    assert(cast(int)reg["age"]);

    // // Update it
    reg["age"] = 25;
    assert(cast(int)reg["age"] == 25);

    // Obtain a handle on the configuration
    // entry, then update it and read it back
    // to confirm
    ConfigEntry* ageEntry = "age" in reg;
    *ageEntry = ConfigEntry.ofNumeric(69_420);
    assert(cast(int)reg["age"] == 69_420);

    // Should not be able to set entry it not yet existent
    try
    {
        reg.setEntry("male", ConfigEntry.ofFlag(true));
        assert(false);
    }
    catch(RegistryException e)
    {

    }

    // All entries
    RegistryEntry[] all = reg[];
    assert(all.length == 2);
    writeln(all);
}