-module(rebar3_appup_compile).

-export([init/1,
         do/1,
         format_error/1]).

-define(PROVIDER, compile).
-define(DEPS, [{default, app_discovery}]).

%% ===================================================================
%% Public API
%% ===================================================================
-spec init(rebar_state:t()) -> {ok, rebar_state:t()}.
init(State) ->
    Provider = providers:create([
            {name, ?PROVIDER},            % The 'user friendly' name of the task
            {namespace, appup},
            {module, ?MODULE},            % The module implementation of the task
            {bare, true},                 % The task can be run by the user, always true
            {deps, ?DEPS},                % The list of dependencies
            {opts, []},                   % list of options understood by the plugin
            {example, "rebar3 appup compile"},
            {short_desc, "Compile and validate all .appup.src files"},
            {desc, "Appup compile"}
    ]),
    {ok, rebar_state:add_provider(State, Provider)}.

-spec do(rebar_state:t()) -> {ok, rebar_state:t()} | {error, string()}.
do(State) ->
    Apps = case rebar_state:current_app(State) of
            undefined ->
                rebar_state:project_apps(State);
            AppInfo ->
                [AppInfo]
           end,
    lists:foreach(fun(AppInfo) ->
        Opts = rebar_app_info:opts(AppInfo),
        SrcDirs = rebar_dir:src_dirs(Opts, ["src"]),
        rebar_base_compiler:run(Opts, [],
                                SrcDirs, ".appup.src",
                                rebar_app_info:ebin_dir(AppInfo), ".appup",
                                fun(Source, Target, Config) ->
                                    compile(Source, Target, Config)
                                end)
    end, Apps),
    {ok, State}.

-spec format_error(any()) ->  iolist().
format_error(Reason) ->
    io_lib:format("~p", [Reason]).

%% ===================================================================
%% Private API
%% ===================================================================
compile(Source, Target, _Config) ->
    %% Perform basic validation on the appup file
    %% i.e. if a consult succeeds and basic appup
    %% structure exists.
    case file:consult(Source) of
        %% The .appup syntax is described in
        %% http://erlang.org/doc/man/appup.html.
        {ok, [{_Vsn, UpFromVsn, DownToVsn} = AppUp]}
          when is_list(UpFromVsn), is_list(DownToVsn) ->
            case file:write_file(
                   Target,
                   lists:flatten(io_lib:format("~p.", [AppUp]))) of
                {error, Reason} ->
                    rebar_api:abort("Failed writing to target file ~s due to ~s",
                           [Target, Reason]);
                ok -> ok
            end;
        {error, Reason} ->
            rebar_api:abort("Failed to compile ~s: ~p~n", [Source, Reason]);
        _ ->
            rebar_api:abort("Failed to compile ~s, not an appup~n", [Source])
    end.
