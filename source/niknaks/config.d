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

    @disable
    private this();

    private this(ConfigValue value, ConfigType type)
    {
        this.value = value;
        this.type = type;
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

    private bool ensureTypeMatch0(ConfigType requested)
    {
        return this.type == requested;
    }

    // TODO: Add a check for "value set"

    private void ensureTypeMatch(ConfigType requested)
    {
        if(!ensureTypeMatch0(requested))
        {
            throw new ConfigException(format("The entry is not of type '%s'", requested));
        }
    }

    public int numeric()
    {
        ensureTypeMatch(ConfigType.NUMERIC);
        return this.value.integer;
    }

    public string[] array()
    {
        ensureTypeMatch(ConfigType. ARRAY);
        return this.value.textArray;
    }

    public string[] opSlice()
    {
        return array();
    }

    public bool flag()
    {
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
        ensureTypeMatch(ConfigType.TEXT);
        return this.value.text;
    }
}

unittest
{
    ConfigEntry entry = ConfigEntry.ofArray(["hello", "world"]);
    assert(entry[] == ["hello", "world"]);
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