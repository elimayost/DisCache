-module(mycache).
-export([start/0, stop/0]).
-export([put/2, get/1, remove/1]).
-export([init/1, terminate/2, handle_call/3, handle_cast/2, handle_info/2, code_change/3]).
-behaviour(gen_server).
-include("mycache.hrl").

% start/stop functions

start() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

stop() ->
	gen_server:cast(?MODULE, stop).

% interface functions

put(Key, Value) ->
	gen_server:call(?MODULE, {put, Key, Value}).

get(Key) ->
	gen_server:call(?MODULE, {get, Key}).

remove(Key) ->
	gen_server:call(?MODULE, {remove, Key}).

% Callback functions

init(_) ->
	application:start(mnesia),
	mnesia:wait_for_tables([mycache], infinity),
	{ok, []}.

terminate(_Reason, _State) ->
	application:stop(mnesia).	

handle_cast(stop, State) ->
	{stop, normal, State}.

handle_call({put, Key, Value}, _From, State) ->
	Rec = #mycache{key = Key, value = Value},
	F = fun() ->
		case mnesia:read(mycache, Key) of
			[] ->
				mnesia:write(Rec),
				ok;
			[#mycache{value = OldValue}] ->
				mnesia:write(Rec),
				OldValue
		end
	end,
	{atomic, Result}  = mnesia:transaction(F),
	{reply, Result, State};

handle_call({get, Key}, _From, State) ->
	case mnesia:dirty_read(mycache, Key) of
		[#mycache{value = Value}] -> {reply, Value, []};
		_ 												-> {reply, not_found, State}
	end;					

handle_call({remove, Key}, _From, State) ->
	F = fun() ->
		case mnesia:read(mycache, Key) of
			[] ->
				not_found;
			[#mycache{value = Value}] ->
				mnesia:delete({mycache, Key}),
				Value
		end
	end,
	{atomic, Result} = mnesia:transaction(F),
	{reply, Result, State}.

handle_info(_Info, State) ->
	{no_reply, State}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.






