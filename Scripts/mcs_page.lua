-- ModCoreSettings' own page, contributed like any module's page and attached to its
-- folder, so it takes the mod's name, author and icon from mod.json. The Templates tab
-- (MCS_Page 1) is a slot that ModCore Templates fills; browser_groups appends the
-- Developer Tools tab (5) on every build.
return {
    storage={file='config.ini',section='Modules'},
    groups={
        {id='Pages',heading=false},
        -- The Modules tab's settings, under a Listing heading.
        {id='Listing',conditions={visible={field='MCS_Page',values={0}}}},
        -- Then slots that UE4SS Lua Extensions fills from its own hidden pages: how many
        -- extensions are installed, and, in a subgroup, each one's startup verification switch.
        {id='Extensions',label='Lua Extensions',conditions={visible={field='MCS_Page',values={0}}},groups={
            {id='Verifications',label='Verify Extensions on Startup',conditions={visible={field='MCS_Page',values={0}}}}}},
        -- The Templates tab: one slot that ModCore Templates fills with every loaded template.
        {id='Templates',heading=false,conditions={visible={field='MCS_Page',values={1}}}},
    },
    fields={
        {id='MCS_Page',group='Pages',label='Page',heading=true,action=true,default=0,
            choices={{value=0,label='Modules'},{value=1,label='Templates'},{value=5,label='Developer Tools'}}},
        -- Stored as SortBy: 2 newest first, 1 by category, 0 alphabetically, 3 load
        -- order. The mod list's Sort by button (sort_button) cycles the same values.
        {id='SortBy',group='Listing',label='Sort by',default=1,
            choices={{value=2,label='Recently Added'},{value=1,label='Categories'},{value=0,label='Alphabetical'},
                {value=3,label='Load Order'}}},
        {id='PreferredCategoryMinimum',group='Listing',label='Collections valid with # modules',default=2,
            conditions={visible={field='SortBy',values={1}}},
            choices={{value=0,label='No'},{value=2,label='2'},{value=3,label='3'}}},
        -- A mod whose categories span several top categories is listed under each, or only
        -- under the one holding most of them (ties: the first declared).
        {id='SingleCategory',group='Listing',label='Modules appear in a single category',default=0,
            conditions={visible={field='SortBy',values={1}}},
            choices={{value=0,label='Off'},{value=1,label='On'}}},
        -- Grid columns of every group, shown in every sort; the ungrouped lists are one mod per line.
        {id='ModulesPerRow',group='Listing',label='Modules per row',default=2,
            choices={{value=1,label='1'},{value=2,label='2'},{value=3,label='3'}}},
        -- Shown as is until UE4SS Lua Extensions fills them (settings:extensions, :verifications).
        {id='MCS_Extensions',group='Extensions',label='Installed extensions',readOnly=true,default=0,
            choices={{value=0,label='None'}},slot='extensions',slotLabel=true},
        {id='MCS_Verifications',group='Verifications',label='Extensions',readOnly=true,default=0,
            choices={{value=0,label='Not installed'}},slot='verifications'},
        -- Shown as is until ModCore Templates fills it (settings:templates); its rows keep
        -- their own groups, one heading per template category.
        {id='MCS_Templates',group='Templates',label='Templates',readOnly=true,default=0,
            choices={{value=0,label='None loaded'}},slot='templates',slotGroups=true},
    },
}
