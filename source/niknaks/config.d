module niknaks.config;

import std.string : format;


version(unittest)
{
    import std.stdio : writeln;
}

private union ConfigValue
{
    string text;
    int integer;
    bool flag;
    string[] textArray;
}

public enum ConfigType
{
    TEXT,
    NUMERIC,
    FLAG,
    ARRAY
}

public final class ConfigException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

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

public final class RegistryException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

public struct RegistryEntry
{
    private string name;
    private ConfigEntry val;

    this(string name, ConfigEntry entry)
    {
        this.name = name;
        this.val = entry;
    }

    public string getName()
    {
        return this.name;
    }

    public ConfigEntry getEntry()
    {
        return this.val;
    }
}

public struct Registry
{
    private ConfigEntry[string] entries;
    private bool allowOverwriteEntry;

    this(bool allowOverwritingOfEntries)
    {
        setAllowOverwrite(allowOverwritingOfEntries);
    }

    

    public bool hasEntry(string name)
    {
        return getEntry0(name) !is null;
    }

    private ConfigEntry* getEntry0(string name)
    {
        ConfigEntry* potEntry = name in this.entries;
        return potEntry;
    }


    public ConfigEntry* opBinaryRight(string op)(string name)
    if(op == "in")
    {
        return getEntry0(name);
    }

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

    public ConfigEntry opIndex(string name)
    {
        ConfigEntry entry;
        if(!getEntry_nothrow(name, entry))
        {
            throw new RegistryException(format("Cannot find an entry by the name of '%s'", name));
        }

        return entry;
    }

    public void setAllowOverwrite(bool flag)
    {
        this.allowOverwriteEntry = flag;
    }

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

    public void newEntry(string name, ConfigEntry entry)
    {
        newEntry(name, entry, this.allowOverwriteEntry, true);
    }

    // TOD: Add on-the-spot ConfigEntry creastion

    public void newEntry(string name, int numeric)
    {
        newEntry(name, ConfigEntry.ofNumeric(numeric));
    }

    public void newEntry(string name, string text)
    {
        newEntry(name, ConfigEntry.ofText(text));
    }

    public void newEntry(string name, bool flag)
    {
        newEntry(name, ConfigEntry.ofFlag(flag));
    }

    public void newEntry(string name, string[] array)
    {
        newEntry(name, ConfigEntry.ofArray(array));
    }

    public void setEntry(string name, ConfigEntry entry)
    {
        newEntry(name, entry, this.allowOverwriteEntry, false);
    }

    

    // ALlows overwriting ALWAYS
    // or should it NOT?

    /** 
     * Assigns the provided configuration
     * entry to the provided name
     *
     * Take note that using this method
     * will both create the entry if it
     * does not yet exist
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