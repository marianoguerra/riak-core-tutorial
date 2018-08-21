Making it a persistent KV Store with leveled backend
====================================================

.. note::

    The content of this chapter is in the `07-leveled-kv` branch.

    https://gitlab.com/marianoguerra/tanodb/tree/07-leveled-kv

Implementing it
---------------

Until now we have an in memory key-value store, what do we have to do to make
it a persistent one?

We would need to implement a new kv backend, that implements the same API as
`tanodb_kv_ets` but using a library that persists to disk.

For this we are going to use `leveled <https://github.com/martinsumner/leveled>`_ a pure erlang implementation of
leveldb.

Being pure erlang means it's easy to build on any platform and easy to
understand and contribute since it's all erlang!

The changes will involve making room for configurable KV backends, for that we
will keep the backend module in a field called kv_mod in the vnode state:

.. code-block:: erlang

	-record(state, {partition, kv_state, kv_mod}).

On `init` we will pass an extra field to the KV backend init function with the
base path where it can safely store files without clashing with other vnodes in
the same node:

.. code-block:: erlang

	init([Partition]) ->
		DataPath = application:get_env(tanodb, data_path, "."),
		KvMod = tanodb_kv_leveled,
		{ok, KvState} = KvMod:new(#{partition => Partition,
									data_path => DataPath}),
		{ok, #state { partition=Partition, kv_state=KvState, kv_mod=KvMod }}.

We are getting the base path to store data from an environment variable
(`tanodb.data_path`), to make it configurable we need to add it to our cuttlefish
schema on `priv/01-tanodb.schema`:

.. code-block:: erlang

	%% @doc base folder where data is stored
	{mapping, "paths.data", "tanodb.data_path", [
	  {datatype, directory},
	  {default, "{{platform_data_dir}}/vnodes"}
	]}.

Then we need to replace all the places in `tanodb_vnode` where we used
`tanodb_kv_ets` to use the value of `kv_mod` from the `state` record.

On `rebar.config` we need to add the `leveled` dependency, since it doesn't
have any release and it's not on `hex.pm <https://hex.pm/>`_ we will reference
the `master` branch from the github repo:

.. code-block:: erlang

	{deps, [cowboy, jsx, recon,
		{riak_core, {pkg, riak_core_ng}},
		{leveled, {git, "https://github.com/martinsumner/leveled.git", {branch, "master"}}}
	]}.

We specify in the release to load `leveled` and its dependency `lz4`:

.. code-block:: erlang

	{relx, [{release, { tanodb , "0.1.0"},
			 [tanodb,
			  cuttlefish,
			  cowboy,
			  {leveled, load},
			  {lz4, load},
			  jsx,
			  sasl]},

At this point in time, to be able to compile leveled on Erlang 20.3, we need
to add an override to remove the `warnings_as_errors` option in `erl_opts`:

.. code-block:: erlang

	{override, leveled,
		[{erl_opts, [{platform_define, "^1[7-8]{1}", old_rand},
			{platform_define, "^R", old_rand},
			{platform_define, "^R", no_sync}]}]}


The code for `apps/tanodb/src/tanodb_kv_leveled.erl`:

.. code-block:: erlang

	-module(tanodb_kv_leveled).
	-export([new/1, get/3, put/4, delete/3, keys/2, dispose/1, delete/1,
			 is_empty/1, foldl/3]).

	-include_lib("leveled/include/leveled.hrl").

	-record(state, {bookie, base_path}).

	new(#{partition := Partition, data_path := DataPath}) ->
		Path = filename:join([DataPath, "leveled", integer_to_list(Partition)]),
		{ok, Bookie} = leveled_bookie:book_start(Path, 2000, 500000000, none),
		State = #state{bookie=Bookie, base_path=Path},
		{ok, State}.

	put(State=#state{bookie=Bookie}, Bucket, Key, Value) ->
		R = leveled_bookie:book_put(Bookie, Bucket, Key, Value, []),
		{R, State}.

	get(State=#state{bookie=Bookie}, Bucket, Key) ->
		K = {Bucket, Key},
		Res = case leveled_bookie:book_get(Bookie, Bucket, Key) of
				  not_found -> {not_found, K};
				  {ok, Value} -> {found, {K, Value}}
			  end,
		{Res, State}.

	delete(State=#state{bookie=Bookie}, Bucket, Key) ->
		R = leveled_bookie:book_delete(Bookie, Bucket, Key, []),
		{ok, State}.

	keys(State=#state{bookie=Bookie}, Bucket) ->
		FoldHeadsFun = fun(_B, K, _ProxyV, Acc) -> [K | Acc] end,
		{async, FoldFn} = leveled_bookie:book_returnfolder(Bookie,
								{foldheads_bybucket,
									?STD_TAG,
									Bucket,
									all,
									FoldHeadsFun,
									true, true, false}),
		Keys = FoldFn(),
		{Keys, State}.

	is_empty(State=#state{bookie=Bookie}) ->
		FoldBucketsFun = fun(B, Acc) -> [B | Acc] end,
		{async, FoldFn} = leveled_bookie:book_returnfolder(Bookie,
														   {binary_bucketlist,
															?STD_TAG,
															{FoldBucketsFun, []}}),
		IsEmpty = case FoldFn() of
					  [] -> true;
					  _ -> false
				  end,
		{IsEmpty, State}.

	dispose(State=#state{bookie=Bookie}) ->
		ok = leveled_bookie:book_close(Bookie),
		{ok, State}.

	delete(State=#state{base_path=Path}) ->
		R = remove_path(Path),
		{R, State}.

	foldl(Fun, Acc0, State=#state{bookie=Bookie}) ->
		FoldObjectsFun = fun(B, K, V, Acc) -> Fun({{B, K}, V}, Acc) end,
		{async, FoldFn} = leveled_bookie:book_returnfolder(Bookie, {foldobjects_allkeys,
																	?STD_TAG,
																	{FoldObjectsFun, Acc0},
																	true}),
		AccOut = FoldFn(),
		{AccOut, State}.

	% private functions

	sub_files(From) ->
		{ok, SubFiles} = file:list_dir(From),
		[filename:join(From, SubFile) || SubFile <- SubFiles].

	remove_path(Path) ->
		case filelib:is_dir(Path) of
			false ->
				file:delete(Path);
			true ->
				lists:foreach(fun(ChildPath) -> remove_path(ChildPath) end,
							  sub_files(Path)),
				file:del_dir(Path)
		end.

Trying it
---------

From the user perspective nothing changed other than the fact that the data will
persist between restarts.

To test it redo the "Trying it" sections from the Handoff and Coverage Calls
chapters.
