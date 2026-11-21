# json 1.0.0 - JSON stringification helpers
public def json_int(n int) -> str:
    return str(n)

public def json_bool(b bool) -> str:
    if b:
        return "true"
    return "false"

public def json_str(s str) -> str:
    return "\"" + s + "\""

public def json_null() -> str:
    return "null"
