-- ModCoreSettings' own page, contributed like any module's page and attached to its
-- folder, so it takes the mod's name, author and icon from mod.json. The Templates tab
-- (MCS_Page 1) is a slot that ModCore Templates fills; browser_groups appends the
-- Developer Tools tab (5) on every build.
return {
    storage={file='config.ini',section='Modules'},
    groups={
        {id='Pages',style='none'},
        -- The Modules tab's settings, under Options, Listing and Previews headings.
        {id='Options',conditions={visible={field='MCS_Page',values={0}}}},
        {id='Listing',conditions={visible={field='MCS_Page',values={0}}}},
        {id='Previews',conditions={visible={field='MCS_Page',values={0}}}},
        -- The Templates tab: one slot that ModCore Templates fills with every loaded template.
        {id='Templates',style='none',conditions={visible={field='MCS_Page',values={1}}}},
    },
    fields={
        {id='MCS_Page',group='Pages',label='Page',style='title',action=true,default=0,
            values={{value=0,label='Modules'},{value=1,label='Templates'},{value=5,label='Developer Tools'}}},
        -- Stored as CompactStyle; compact_style applies it each time the menu opens.
        {id='CompactStyle',group='Options',label='Use Compact Style',default='off',
            description='In a loaded game, the menu takes the pause menu\'s look: the game blurred behind it and the list in a dark panel down the left, one module per row. Index applies it to the mod list, Everywhere to every page. It shows the next time the menu opens.',
            values={{key='off',label='Off'},{key='index',label='Index'},{key='everywhere',label='Everywhere'}}},
        -- Stored as SortBy: 2 newest first, 1 by category, 0 alphabetically, 3 load
        -- order. The mod list's Sort by button (sort_button) cycles the same values.
        {id='SortBy',group='Listing',label='Sort by',default=1,
            description='How the mod list is ordered. The mod list\'s Sort by button cycles through the same choices.',
            values={{value=2,label='Recently Added',
                    description='Newest installs and updates first, under Last 24 hours, Last 7 days, Last 30 days and Earlier.'},
                {value=1,label='Categories',
                    description='Grouped by category, and by collection where enough mods share one.'},
                {value=0,label='Alphabetical',description='One list, by name.'},
                {value=3,label='Load Order',description='One list in the order UE4SS loads the mods, each numbered.'}}},
        {id='PreferredCategoryMinimum',group='Listing',label='Collections valid with # modules',default=2,
            description='Mods can name a collection in their mod.json. It becomes its own group once this many installed mods name it, and those mods are listed only there. No turns collections off.',
            conditions={visible={field='SortBy',values={1}}},
            values={{value=0,label='No'},{value=2,label='2'},{value=3,label='3'}}},
        -- A mod whose categories span several top categories is listed under each, or only
        -- under the one holding most of them (ties: the first declared).
        {id='SingleCategory',group='Listing',label='Modules appear in a single category',default=0,
            description='On lists a mod whose categories span several top categories only under the one holding most of them. Off lists it under each.',
            conditions={visible={field='SortBy',values={1}}},
            values={{value=0,label='Off'},{value=1,label='On'}}},
        -- Grid columns of every list, shown and applied in every sort.
        {id='ModulesPerRow',group='Listing',label='Modules per row',default=2,
            description='Columns in the mod list, in every sort.',
            values={{value=1,label='1'},{value=2,label='2'},{value=3,label='3'}}},
        -- The live preview's two buttons (preview_panel), which save their clicks here too.
        {id='PreviewSound',group='Previews',label='Play sound in previews',default='auto',
            description='Whether a page\'s live preview plays its sounds. The Sound button under the preview cycles the same choices.',
            values={{key='auto',label='Auto',
                    description='Only while the selected setting is about sound, such as a sound or its volume.'},
                {key='on',label='On',description='Always.'},
                {key='off',label='Off',description='Never.'}}},
        {id='PreviewBackground',group='Previews',label='Background in previews',default='on',
            description='How a page\'s live preview shows its background picture, so what is drawn over it stands out. The Background button under the preview cycles the same choices.',
            values={{key='on',label='On',description='The picture as it is.'},
                {key='blurred',label='Blurred',description='The picture blurred.'},
                {key='dimmed',label='Dimmed',description='The picture faded to 30%.'},
                {key='off',label='Off',description='A plain dim light blue screen instead of the picture.'}}},
        -- Shown as is until ModCore Templates fills it (settings:templates); its rows keep
        -- their own groups, one heading per template category.
        {id='MCS_Templates',group='Templates',label='Templates',widget='text',default=0,
            values={{value=0,label='None loaded'}},slot='templates',slotGroups=true},
    },
}
