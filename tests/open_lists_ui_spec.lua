-- Real adapter and native-card UI constructors with mocked game rendering.
dofile('tests/adapter_spec.lua')
local D=DRAFTOUT
D.mode='local';D.local_launcher=true
assert(dofile('config.lua').pick_seconds=='scaling')
assert(dofile('config.lua').open_deck_lists==false)
G.FUNCS.draftout_open_lists_toggle()
assert(D.mod.config.open_deck_lists and D.settings_ui.open_lists=='Open deck lists: On')
local s=D.start('OPEN-LISTS')
assert(s.open_deck_lists and not D.open_lists.available())
G.FUNCS.draftout_open_lists_toggle()
assert(D.mod.config.open_deck_lists,'Settings stay locked during the draft')
while not s.done do
    local seat=D.core.next_seat(s)
    assert(D.core.submit(s,seat,{s.current[seat].cards[1]},D.core.token(s,seat)))
end
assert(D.open_lists.available())
G.FUNCS.draftout_open_lists()
assert(D.open_lists.open)
local screen=D.screen()
assert(screen.n==G.UIT.C)
for _,node in ipairs(screen.nodes) do assert(node.n==G.UIT.R,'All gallery content stacks vertically') end
assert(D.open_lists.seat==1 and D.open_lists.page==1)
G.FUNCS.draftout_lists_next_page();assert(D.open_lists.page==2)
G.FUNCS.draftout_lists_prev_seat();assert(D.open_lists.seat==4 and D.open_lists.page==1)
G.FUNCS.draftout_lists_next_seat();assert(D.open_lists.seat==1)
G.FUNCS.draftout_lists_prev_page();assert(D.open_lists.page==2)
G.FUNCS.draftout_close_lists();assert(not D.open_lists.open)
-- The setup controls also remain rows: adding a setting cannot create columns.
assert(D.draft_settings().n==G.UIT.R)
D.local_launcher=true;G.FUNCS.draftout_open_lists_toggle()
assert(not D.mod.config.open_deck_lists)
D.local_launcher=false
assert(D.open_lists.available(),'Saved draft retains the option it started with')
G.STAGES={RUN=2};G.STAGE=2
assert(not D.open_lists.available(),'No pregame roster viewer during an active run')
G.STAGE=1
D.start('CLOSED-LISTS')
assert(not D.open_lists.open and not D.mod.config.session.open_deck_lists)
print('Open-list UI, local lifecycle, saved options and default timer checks passed')
