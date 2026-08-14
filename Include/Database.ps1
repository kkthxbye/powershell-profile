$env:SNOWFLAKE_DISABLE_PLATFORM_DETECTION = 'true'
function snowsqlps {
    snow sql --silent --format csv $args | Out-String | ConvertFrom-Csv
}

function sqlite3ps {
    sqlite3 --csv --header $args | ConvertFrom-Csv
}
