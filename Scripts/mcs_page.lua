-- ModCoreSettings' own page, contributed like any module's page and attached to its
-- folder, so it takes the mod's name, author and icon from mod.json. browser_groups
-- appends the Errors (MCS_Page 4) and Developer Tools (5) tabs on every build.
return {
    storage={file='config.ini',section='Modules'},
    groups={
        {id='Pages',heading=false},
        -- The Modules tab's settings, under a Listing heading.
        {id='Listing',visible={field='MCS_Page',values={0}}},
    },
    fields={
        {id='MCS_Page',group='Pages',label='Page',level=1,action=true,default=0,
            choices={{value=0,label='Modules'},{value=4,label='Errors'},{value=5,label='Developer Tools'}}},
        -- Stored as SortBy: 2 newest first, 1 by category, 0 alphabetically, 3 load
        -- order. The mod list's Sort by button (sort_button) cycles the same values.
        {id='SortBy',group='Listing',label='Sort by',default=1,
            choices={{value=2,label='Recently Added'},{value=1,label='Categories'},{value=0,label='Alphabetical'},
                {value=3,label='Load Order'}}},
        {id='PreferredCategoryMinimum',group='Listing',label='Collections valid with # modules',default=2,
            visible={field='SortBy',values={1}},
            choices={{value=0,label='No'},{value=2,label='2'},{value=3,label='3'}}},
        -- A mod whose categories span several top categories is listed under each, or only
        -- under the one holding most of them (ties: the first declared).
        {id='SingleCategory',group='Listing',label='Modules appear in a single category',default=0,
            visible={field='SortBy',values={1}},
            choices={{value=0,label='Off'},{value=1,label='On'}}},
        -- Grid columns of every group; the ungrouped lists are one mod per line.
        {id='ModulesPerRow',group='Listing',label='Modules per row',default=2,
            visible={field='SortBy',values={1,2}},
            choices={{value=1,label='1'},{value=2,label='2'},{value=3,label='3'}}},
    },
}
