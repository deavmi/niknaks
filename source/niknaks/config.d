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
    int integer;
    bool flag;
    string[] textArray;
}

/** 
 * The type of the entry
 */
public enum ConfigType
{
    TEXT,
    NUMERIC,
    FLAG,
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

    // If set at all
    private bool isSet = false;

    private void ensureSet()
    {
        if(!this.isSet)
        {
            throw new ConfigException("This config entry has not yet been set");
        }
    }

    private void set()
    {
        this.isSet = true;
    }

    // TODO: Must have an unset flag
    // @disable
    // private this();

    private this(ConfigValue value, ConfigType type)
    {
        this.value = value;
        this.type = type;

        set();
    }

    public static ConfigEntry ofText(string text)
    {
        ConfigValue tmp;
        tmp.text = text;
        return ConfigEntry(tmp, type.TEXT);
    }

    public static ConfigEntry ofNumeric(int i)
    {
        ConfigValue tmp;
        tmp.integer = i;
        return ConfigEntry(tmp, type.NUMERIC);
    }

    public static ConfigEntry ofFlag(bool flag)
    {
        ConfigValue tmp;
        tmp.flag = flag;
        return ConfigEntry(tmp, type.FLAG);
    }

    public static ConfigEntry ofArray(string[] array)
    {
        ConfigValue tmp;
        tmp.textArray = array;
        return ConfigEntry(tmp, type.ARRAY);
    }

    public ConfigType getType()
    {
        return this.type;
    }

    private bool ensureTypeMatch0(ConfigType requested)
    {
        return getType() == requested;
    }

    private void ensureTypeMatch(ConfigType requested)
    {
        if(!ensureTypeMatch0(requested))
        {
            throw new ConfigException(format("The entry is not of type '%s'", requested));
        }
    }

    public int numeric()
    {
        ensureSet;
        ensureTypeMatch(ConfigType.NUMERIC);
        return this.value.integer;
    }

    public string[] array()
    {
        ensureSet;
        ensureTypeMatch(ConfigType. ARRAY);
        return this.value.textArray;
    }

    public string[] opSlice()
    {
        return array();
    }

    public bool flag()
    {
        ensureSet;
        ensureTypeMatch(ConfigType.FLAG);
        return this.value.flag;
    }

    public bool isTrue()
    {
        return flag() == true;
    }

    public bool isFalse()
    {
        return flag() == false;
    }

    public string text()
    {
        ensureSet;
        ensureTypeMatch(ConfigType.TEXT);
        return this.value.text;
    }

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
        else static if(__traits(isSame, T, int))
        {
            return numeric();
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
    public void opIndexAssign(int numeric, string name)
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
    reg.newEntry("name", ConfigEntry.ofText("Tristan"));

    // Check it exists
    assert(reg.hasEntry("name"));

    // Adding it again should fail
    try
    {
        reg.newEntry("name", ConfigEntry.ofText("Tristan2"));
        assert(false);
    }
    catch(RegistryException e)
    {

    }

    // Check that the entry still has the right value
    assert(cast(string)reg["name"] == "Tristan");

    // Add a new entry and test its prescence
    reg["age"] = 24;
    assert(cast(int)reg["age"] == 24);

    // Update it
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