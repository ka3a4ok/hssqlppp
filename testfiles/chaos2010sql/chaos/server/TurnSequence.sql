/*
================================================================================

= turn sequence

see readme for overview of turn sequence

For the player, there are three phases, but for the computer there are
four phases, the extra one is the autonomous phase in between casting
and moving. In this phase magic fire and gooey blob spread, castles
may disappear, and wizards may receive a new spell from a magic tree.

There are lots of constraints in this section. For an app like this
where all the updates are through stored procs which carefully check
their preconditions, and there are never any multiple updates, this is
a bit excessive. The main takeaway is that you need deferred
constraints or multiple updates for most constraints that involve more
that one table.

== ddl
*/
select module('Chaos.Server.TurnSequence');

/*
use this to simulate multiple updates:
for a constraint which refers to multiple tables which get updated
during an action_next_phase call, this will be set to true,
false at all other times, so using this can defer constraint checking
till the end of the action_next_phase call after all the relevant
turn phase relvars have been updated. Don't forget to put
in_next_phase_hack_table in the relvar list for the constraint.

*/
select create_var('in_next_phase_hack', 'boolean');
insert into in_next_phase_hack_table values (false);
--select set_relvar_type('in_next_phase_hack_table', 'stack');

select create_var('creating_new_game', 'boolean');
insert into creating_new_game_table values (true);
--select set_relvar_type('creating_new_game_table', 'stack');

--Turn number, starts at 0 goes up 1 each full turn, just used to provide
--info on how long the game has been going.
select create_var('turn_number', 'int');
--select set_relvar_type('turn_number_table', 'data');

--if not creating new game cardinality = 1
/*
select create_update_transition_tuple_constraint(
  'turn_number_table',
  'turn_number_change_valid',
  '(NEW.turn_number = OLD.turn_number + 1)');
*/
/*create function no_deletes_inserts_except_new_game(relvar_name text)
  returns void as $$
begin
  perform create_delete_transition_tuple_constraint(
    relvar_name,
    relvar_name || '_no_delete',
    'exists(select 1 from creating_new_game_table
      where creating_new_game = true)');
  perform create_insert_transition_tuple_constraint(
    relvar_name,
    relvar_name || '_no_insert',
    'exists(select 1 from creating_new_game_table
      where creating_new_game = true)');

end;
$$ language plpgsql volatile;
*/
--select no_deletes_inserts_except_new_game('turn_number_table');

/*
turn phase
must follow choose-cast-auto-move-choose-etc.

wizard spell choices
added row must be for current wizard, and in current wizard's spell book
  in choose phase
removed row must be for current wizard
  in cast phase

spell parts to cast
pieces to move
squares left to walk

*/

create view next_wizard as
select wizard_name, new_wizard_name from
  (select wizard_name as new_wizard_name, place
     from live_wizards) as a inner join
  (select wizard_name,
     (place + 1) %
       (select max(place) + 1 from live_wizards)
      as old_place from live_wizards) as b
  on (place = old_place);


create function next_wizard(text) returns text as $$
  select new_wizard_name from next_wizard
    where wizard_name = $1;
$$ language sql stable;

/*select next_wizard('Buddha');
select next_wizard('Kong Fuzi');
select next_wizard('Laozi');
select next_wizard('Moshe');
select next_wizard('Muhammad');
select next_wizard('Shiva');
select next_wizard('Yeshua');
select next_wizard('Zarathushthra');
*/

--current wizard is the wizard who's turn it is to do stuff in current phase
select create_var('current_wizard', 'text');
--select set_relvar_type('current_wizard_table', 'data');
--select add_foreign_key('current_wizard_table', 'current_wizard',
--  'wizards', 'wizard_name');
/*select create_update_transition_tuple_constraint(
  'current_wizard_table',
  'next_wizard_change_valid',
  'NEW.current_wizard = next_wizard(OLD.current_wizard)');
select create_delete_transition_tuple_constraint(
    'current_wizard_table',
    'current_wizard_table_no_delete',
    'exists(select 1 from creating_new_game_table
      where creating_new_game = true)
     or exists (select 1 from game_completed_table)');
select create_insert_transition_tuple_constraint(
    'current_wizard_table',
    'current_wizard_table_no_insert',
    'exists(select 1 from creating_new_game_table
      where creating_new_game = true)');
*/

--select no_deletes_inserts_except_new_game('current_wizard_table');
/*select add_constraint('current_wizard_must_be_alive',
  $$(select not expired from current_wizard_table
     inner join wizards on current_wizard = wizard_name)$$,
  array['wizards', 'current_wizard_table']);
*/

/*
wizard field in most tables and views is named wizard_name

instead of tediously writing out inner join blah on wizard_name =
current_wizard use the following view to instead write natural inner
join current_wizard . Not that much less tedious though.

*/

create view current_wizard as
  select current_wizard as wizard_name from current_wizard_table;

--turn phase enum: choose spell, cast spell, autonomous, move
create domain turn_phase_enum as text
       check (value in ('choose', 'cast', 'autonomous', 'move'));

create function next_turn_phase(text) returns text as $$
  select case
    when $1='choose' then 'cast'
    when $1='cast' then 'autonomous'
    when $1='autonomous' then 'move'
    when $1='move' then 'choose'
  end as result
$$ language sql immutable;

select create_var('turn_phase', 'turn_phase_enum');
--select set_relvar_type('turn_phase_table', 'data');
/*select create_update_transition_tuple_constraint(
  'turn_phase_table',
  'turn_phase_change_valid',
  'NEW.turn_phase = next_turn_phase(OLD.turn_phase)');
select no_deletes_inserts_except_new_game('turn_phase_table');
*/
create type turn_pos as (
    turn_number int,
    turn_phase turn_phase_enum,
    current_wizard text
);

-- create function turn_pos_equals(turn_pos, turn_pos) returns boolean as $$
--   select $1.turn_number = $2.turn_number and
--          $1.turn_phase = $2.turn_phase and
--          $1.current_wizard = $2.current_wizard;
-- $$ language sql stable;

-- create operator = (
--     leftarg = turn_pos,
--     rightarg = turn_pos,
--     procedure = turn_pos_equals,
--     commutator = =
-- );

create function get_current_turn_pos() returns turn_pos as $$
  select (turn_number, turn_phase, current_wizard)::turn_pos
    from turn_number_table
    cross join turn_phase_table
    cross join current_wizard_table;
$$ language sql stable;


/*

Both spell casting and moving have a bunch of state local to each
wizards turn in the that phase. Wizard spell choices is a piece of
turn phase state which is constructed bit by bit in the choice phase
then read in the cast phase, so this lasts from the start of the
choice phase to the end of the cast phase.

*/
create table wizard_spell_choices_mr (
  wizard_name text unique not null,
  spell_name text not null,
  imaginary boolean null
);
--select add_key('wizard_spell_choices_mr', 'wizard_name');
/*select add_constraint('dead_wizard_no_spell',
  $$ not exists(select 1 from wizard_spell_choices_mr
    natural inner join wizards
    where expired = true)$$,
  array['wizards', 'pieces']);
*/
create view wizard_spell_choices as
  select wizard_name, spell_name
    from wizard_spell_choices_mr;

create view wizard_spell_choices_imaginary as
  select wizard_name, imaginary
    from wizard_spell_choices_mr
    where imaginary is not null;

/*

todo: add constraint to say imaginary must be set for monsters and
must not be set for non-monsters (will need a multiple update hack to
go with this)

*/

--shortcut for current wizard's spell
create view current_wizard_spell as
  select spell_name from wizard_spell_choices
    natural inner join current_wizard;

create function get_current_wizard_spell() returns text as $$
  select spell_name from current_wizard_spell;
$$ language sql stable;

/*this really needs multiple updates

--select add_foreign_key('wizard_spell_choices', array['wizard_name',
--  'spell_name'], 'spell_books');

the problem is that in the action_next_phase for the end of a wizards
cast phase we want to delete the spell choice from this table, and
also delete the spell from the wizards spell book. The code deletes
the spell from the spell book first, but since the spell choice
references the spell book table, the reference stops the delete.

We can't use a conventional cascade delete since there may be multiple
rows in the spell book for the same spell/wizard combo - this isn't a
foreign key in sql sense.

One alternative is to save the wizard and spell names in a variable so
we can delete the spell choice first then the spell book entry, but
that is pretty inelegant.

We could do it properly with multiple updates, so simulate this by
writing out the fk by hand and adding the in next phase hack.

*/
select create_var('spell_choice_hack', 'boolean');
insert into spell_choice_hack_table values (false);
--select set_relvar_type('spell_choice_hack_table', 'stack');

/*
select add_constraint('wizard_spell_choices_wizard_name_spell_name_fkey',
$$((select spell_choice_hack from spell_choice_hack_table) or
not exists(select wizard_name, spell_name from wizard_spell_choices
  except
select wizard_name, spell_name from spell_books))$$,
array['spell_choice_hack_table', 'wizard_spell_choices_mr', 'spell_books']);
*/

/*
if choose phase: only current and previous wizards may have a row
if cast phase: only current and subsequent wizards may have a row
this constraint really needs multiple updates.
*/
/*
select add_constraint('chosen_spell_phase_valid',
$$
((select in_next_phase_hack from in_next_phase_hack_table) or
(((select turn_phase='choose' from turn_phase_table) and
 (select max(place) from wizard_spell_choices
   natural inner join live_wizards) <=
 (select place from live_wizards
   inner join current_wizard_table
     on wizard_name = current_wizard))
or
((select turn_phase='cast' from turn_phase_table) and
 (select min(place) from wizard_spell_choices
    natural inner join live_wizards) >=
  (select place from live_wizards
    inner join current_wizard_table
      on wizard_name = current_wizard))
or not exists(select 1 from wizard_spell_choices)
))$$, array['turn_phase_table', 'current_wizard_table',
    'wizard_spell_choices_mr', 'wizards', 'in_next_phase_hack_table']);

select create_update_transition_tuple_constraint(
  'wizard_spell_choices_mr',
  'update_spell_choice_restricted',
  $$(select turn_phase = 'choose' from turn_phase_table)
    and (NEW.wizard_name = OLD.wizard_name)
    and (select current_wizard = NEW.wizard_name from current_wizard_table)$$);
select create_insert_transition_tuple_constraint(
  'wizard_spell_choices_mr',
  'insert_spell_choice_restricted',
  $$(select turn_phase = 'choose' from turn_phase_table)
    and (select current_wizard = NEW.wizard_name from current_wizard_table)$$);
select create_delete_transition_tuple_constraint(
  'wizard_spell_choices_mr',
  'delete_spell_choice_restricted',
  $$(select turn_phase in ('cast', 'choose') from turn_phase_table)$$);

select set_relvar_type('wizard_spell_choices_mr', 'data');
*/
/*

if wizard is skipping casting a spell then no tuple appears in this
relvar for that wizard

spellparts to cast is local to spell casting phase for each wizard

current wizard has cast amount spell parts in this turn phase

when entering spell cast phase, this is set to 0 if wizard has no
spell or max number of casts otherwise

*/

select create_var('spell_parts_to_cast', 'int');
--select set_relvar_type('spell_parts_to_cast_table', 'data');
/*
select add_constraint('parts_to_cast_only', $$
  ((select turn_phase = 'cast' from turn_phase_table)
  or not exists(select 1 from spell_parts_to_cast_table))
$$, array['turn_phase_table', 'spell_parts_to_cast_table']);
*/
/*
If casting multipart spell, only check success on first part.
Store whether current wizard's spell needs a success check here.
make sure to reset it each next phase during cast phase
*/

select create_var('cast_success_checked', 'boolean');
--select set_relvar_type('cast_success_checked_table', 'data');
/*select add_constraint('cast_checked_cast_only', $$
  ((select turn_phase = 'cast' from turn_phase_table)
  or not exists(select 1 from cast_success_checked_table))
$$, array['cast_success_checked_table', 'turn_phase_table']);
*/
/*

casting affecting alignment

how does a successful or unsuccessful spell affect world alignment?
do unsuccessful spells have any effect?
does the current world alignment affect the effect?
is there a limit to how much the alignment can change in a turn?
is each spell's effect independent of what other spells are cast that turn?

what about:
  each spell can affect the world alignment
  spell alignments don't add up, the result is taken by random
    from one of the spells cast that turn
  e.g.
  0, -1, -4, 2, -1: five spells cast with alignments given
    chose one of these at random, each with 1/5 chance
    then adjust alignment by this (align/2 with probability for halfs?)

current plan:
only successful spells affect alignment
keep track of all spells during cast phase
sum up total alignment, divide by 2, each full number affects alignment
the fractional part has probability to affect it
maximum change is 2

this means that law increases alignment by one and large law does it
by two in the absence of any other spells.

*/
select create_var('cast_alignment', 'integer');
--select set_relvar_type('cast_alignment_table', 'stack');
/*
select add_constraint('cast_alignment_empty',
  $$((get_turn_phase() = 'cast') or
  not exists(select 1 from cast_alignment_table))$$,
  array['turn_phase_table', 'cast_alignment_table']);
*/
create function adjust_world_alignment() returns void as $$
declare
  abs_change float;
begin
  select into abs_change
    min(abs(get_cast_alignment()) / 2, 2);
  update world_alignment_table
    set world_alignment = world_alignment
      + trunc(abs_change) * sign(get_cast_alignment());
  --get fractional part
  if (random() < abs_change - trunc(abs_change)) then
    update world_alignment_table
      set world_alignment = world_alignment +
        sign(get_cast_alignment());
  end if;
  update cast_alignment_table set cast_alignment = 0;
end;
$$ language plpgsql volatile;



/*

pieces to move and selected piece are local to move phase for each
wizard

Piece in this table from current wizard's army hasn't yet moved
in this turn.

TODO: i think switching this from pieces to move to pieces_moved will
be a bit more straightforward

*/
create table pieces_to_move (
    ptype text,
    allegiance text,
    tag int,
    unique (ptype,allegiance,tag)
);
--select add_key('pieces_to_move', array['ptype', 'allegiance', 'tag']);
--cascade delete here:
/*select add_foreign_key('pieces_to_move', array['ptype', 'allegiance', 'tag'],
                       'pieces');
select add_foreign_key('pieces_to_move', 'allegiance',
                       'current_wizard_table', 'current_wizard');
select set_relvar_type('pieces_to_move', 'data');
select add_constraint('pieces_to_move_empty',
$$((select turn_phase = 'move' from turn_phase_table) or
not exists (select 1 from pieces_to_move))$$,
array['pieces_to_move', 'turn_phase_table']);
*/
create domain move_phase as text
  check (value in ('motion', 'attack', 'ranged_attack'));

create table selected_piece (
  ptype text,
  allegiance text,
  tag int,
  move_phase move_phase,
  engaged boolean
); -- 0 to 1 tuple when in move phase,
-- piece key from current wizards army, empty otherwise
/*select add_key('selected_piece', array['ptype', 'allegiance', 'tag']);
select add_foreign_key('selected_piece', array['ptype', 'allegiance', 'tag'],
                       'pieces');
select add_foreign_key('selected_piece', 'allegiance',
                       'current_wizard_table', 'current_wizard');
select constrain_to_zero_or_one_tuple('selected_piece');
select set_relvar_type('selected_piece', 'data');
*/

/*

squares left to walk is local to the current moving piece during
its walking phase, not used if piece is not a walker.

TODO: this doesn't take into account e.g. move of 3 squares, move
diagonal, second diagonal move all move used up, can't do three
diagonal moves.

*/
select create_var('remaining_walk', 'int');
--select set_relvar_type('remaining_walk_table', 'data');
select create_var('remaining_walk_hack', 'boolean');
--select set_relvar_type('remaining_walk_hack_table', 'stack');
insert into remaining_walk_hack_table values (false);
/*
select add_constraint('remaining_walk_only_motion',
$$ ((not exists(select 1 from remaining_walk_table)) or
   exists(select 1 from creating_new_game_table
      where creating_new_game = true) or
   (select remaining_walk_hack
     from remaining_walk_hack_table) or
   (exists(select 1 from selected_piece)
      and (select move_phase = 'motion' from selected_piece)
      and exists (select 1 from creature_pieces
                  natural inner join selected_piece)
      and (select not flying from creature_pieces
           natural inner join selected_piece))) $$,
  array['selected_piece', 'pieces', 'remaining_walk_table',
        'remaining_walk_hack_table', 'creating_new_game_table']);
*/
--this function is used to initialise the turn phase data.
create function init_turn_stuff() returns void as $$
begin
  --this should catch attempts to start a game
  --which has already been started
  if exists(select 1 from turn_number_table) then
    raise exception 'new game started when turn number table not empty';
  end if;
  insert into turn_number_table values (0);
  insert into turn_phase_table
    values ('choose');
  insert into current_wizard_table
    select wizard_name from live_wizards
    order by place limit 1;
end;
$$ language plpgsql volatile;

/*

table to cache if the game is over: someone has one or it's a draw.
(This also makes it possible to have a draw when there are wizards
remaining.)

*/

select create_var('game_completed', 'boolean');
--select set_relvar_type('game_completed_table', 'data');
/*select add_constraint('game_completed_wizards',
       $$(not exists(select 1 from game_completed_table)
           or (select count(1) <= 1 from live_wizards))$$,
       array['game_completed_table']);
*/
create function game_completed() returns void as $$
begin
  insert into game_completed_table
    select true where not exists (select 1 from game_completed_table);
end;
$$ language plpgsql volatile;

-- 1 tuple iff current moving piece walks, empty otherwise