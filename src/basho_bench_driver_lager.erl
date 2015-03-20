%% -------------------------------------------------------------------
%%
%% basho_bench: Benchmarking Suite
%%
%% Copyright (c) 2015 Basho Techonologies
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
-module(basho_bench_driver_lager).

-export([new/1,
         run/4]).

-export([keygen/1, valgen/1, sink_generator/0, lager_msg_generator/0]).

-include("basho_bench.hrl").
-include_lib("lager/include/lager.hrl").

-record(state, {
          multiple_sink_support = false
    }).

%% ====================================================================
%% API
%% ====================================================================

new(_ID) ->
    %% I guess it's mildly evil to use the process dictionary to store
    %% stateful things...

    Sinks = basho_bench_config:get(lager_sinks, []),
    erlang:put(lager_sinks, Sinks),

    Levels = basho_bench_config:get(lager_levels, []),
    case Levels == [] of
        true -> erlang:put(lager_levels, ?LEVELS);
        false -> erlang:put(lager_levels, Levels)
    end,

    {ok, #state{multiple_sink_support = erlang:function_exported(lager, log, 5)}}.

run(log, SinkGen, ValueGen, State = #state{multiple_sink_support = S}) ->
    Sink = SinkGen(),
    {Level, Metadata, Format, Args} = ValueGen(),
    Result = case S of
        true ->
            lager:log(Sink, Level, Metadata, Format, Args);
        false ->
            lager:log(Level, Metadata, Format, Args)
    end,
    case Result of
        ok -> {ok, State};
        {error, lager_not_running} -> {'EXIT', lager_not_running};
        {error, Reason} -> {error, Reason, State}
    end.

keygen(_Id) ->
    fun sink_generator/0.

valgen(_Id) ->
    fun lager_msg_generator/0.

sink_generator() ->
    Sinks = erlang:get(lager_sinks),
    get_random(Sinks, lager_event). % TODO - this is hard coded for now because DEFAULT_SINK macro is only in the multiple-sink branch

lager_msg_generator() ->
    Level = get_random(erlang:get(lager_levels), debug),
    Metadata = maybe_generate_metadata(),
    Args = maybe_generate_args(),
    Fmt = generate_fmt(Args),
    {Level, Metadata, Fmt, Args}.

get_random(List, Default) ->
    Len = length(List),
    case Len of
        0 -> Default;
        1 -> hd(List);
        _ -> lists:nth(random:uniform(Len), List)
    end.

maybe_generate_metadata() ->
    [].

maybe_generate_args() ->
    NumArgs = random:uniform(6) - 1,
    generate_args(NumArgs, []).

generate_args(0, Acc) -> lists:reverse(Acc);
generate_args(N, Acc) ->
    Char = random:uniform(26) + 64, % 64 precedes ASCII "A" (65), so this will generate a char in the range of A-Z
    Num  = random:uniform(100),
    generate_args(N - 1, [ list_to_binary(string:chars(Char, Num)) | Acc ]).

generate_fmt(Args) ->
    L = length(Args),
    case L of
        0 -> "No arguments!";
        _ -> string:copies("~p ", L)
    end.
