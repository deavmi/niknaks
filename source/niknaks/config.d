module niknaks.config;

import std.string : format;

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

public final class RegistryException : Exception
{
    this(string msg)
    {
        super(msg);
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

    public ConfigEntry getEntry(string name)
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

    public void newEntry(string name, ConfigEntry entry)
    {
        // Obtain the address of the value that occupies the value
        // the key in the map
        ConfigEntry* entryExist = getEntry0(name);

        // If something is present but overwiritng is disabled
        if((entryExist !is null) && !this.allowOverwriteEntry)
        {
            throw new RegistryException(format("An entry already exists at '%s' and overwriting is not allowed", name));
        }
        // If something is present and overwiring is enabled
        else if(entryExist !is null)
        {
            // Now simply update the data in-place
            *entryExist = entry;
        }
        // If nothing is present
        else
        {
            // Then create the entry
            this.entries[name] = entry;
        }
    }

    public void setEntry(string name, ConfigEntry entry)
    {

    }

    public ConfigEntry opIndex(string name)
    {
        return getEntry(name);
    }

    // public ConfigEntry[] entries()
    // {
    //     ConfigEntry[] entrieS;
    //     foreach(ConfigEntry entry; this.entries)
    //     {

    //     }
    // }
}

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
}