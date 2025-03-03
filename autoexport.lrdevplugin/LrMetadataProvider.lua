return {
    schemaVersion = 1, -- increment this value any time you make a change to the field definitions below

    -- You can have as many fields as you like (the example below shows three)... just make sure each 'id' and 'title' are unique.
    -- Set "searchable" to true to allow as a search criteria in smart collections.
    -- If both "searchable" and "browsable" are true, the field shows up under "Metadata" in Library's grid filter.
    metadataFieldsForPhotos = {{
        dataType = "string",
        searchable = true,
        browsable = true,
        id = "AutoExported",
        title = "Auto-export time"
    }}
}
