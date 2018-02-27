First Command
=============

Get and Put
-----------

tanodb.erl

.. code-block:: erlang

	get(Key) ->
		send_to_one(Key, {get, Key}).

	put(Key, Value) ->
		send_to_one(Key, {put, Key, Value}).

	%% Private Functions

	send_to_one(Key, Cmd) ->
		DocIdx = riak_core_util:chash_key(Key),
		PrefList = riak_core_apl:get_primary_apl(DocIdx, 1, tanodb),
		[{IndexNode, _Type}] = PrefList,
		riak_core_vnode_master:sync_spawn_command(IndexNode, Cmd, tanodb_vnode_master).

tanodb_vnode.erl

.. code-block:: erlang

	-record(state, {partition, table_id}).

	init([Partition]) ->
		TableId = ets:new(?MODULE, [set, {write_concurrency, false},
									{read_concurrency, false}]),

		{ok, #state{partition=Partition, table_id=TableId}}.

.. code-block:: erlang

	handle_command({put, Key, Value}, _Sender,
				   State=#state{table_id=TableId, partition=Partition}) ->
		ets:insert(TableId, {Key, Value}),
		{reply, {ok, Partition}, State};
	handle_command({get, Key}, _Sender,
				   State=#state{table_id=TableId, partition=Partition}) ->
		case ets:lookup(TableId, Key) of
			[] ->
				{reply, {not_found, Partition, Key}, State};
			[{_, Value}] ->
				{reply, {found, Partition, {Key, Value}}, State}
		end;


Delete
------

tanodb.erl

.. code-block:: erlang

	delete(Key) ->
		send_to_one(Key, {delete, Key}).

tanodb_vnode.erl

.. code-block:: erlang

	handle_command({delete, Key}, _Sender,
				   State=#state{table_id=TableId, partition=Partition}) ->
		true = ets:delete(TableId, Key),
		{reply, {ok, Partition}, State};

