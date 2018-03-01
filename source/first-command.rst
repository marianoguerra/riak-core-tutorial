First Command
=============

Implementing Get and Put
------------------------

For our first commands we will copy the general structure of the ping command.

We will start by adding two new functions to tha tanodb.erl file:

.. code-block:: erlang

	get(Key) ->
		send_to_one(Key, {get, Key}).

	put(Key, Value) ->
		send_to_one(Key, {put, Key, Value}).

And generalizing the code used by ping to send a command to one vnode:

.. code-block:: erlang

	%% Private Functions

	send_to_one(Key, Cmd) ->
		DocIdx = riak_core_util:chash_key(Key),
		PrefList = riak_core_apl:get_primary_apl(DocIdx, 1, tanodb),
		[{IndexNode, _Type}] = PrefList,
		riak_core_vnode_master:sync_spawn_command(IndexNode, Cmd, tanodb_vnode_master).

In tanodb_vnode.erl we will need to first create an ETS table per vnode at
initialization and keep a reference to the table_id in the state record:

.. code-block:: erlang

	-record(state, {partition, table_id}).

	init([Partition]) ->
		TableId = ets:new(?MODULE, [set, {write_concurrency, false},
									{read_concurrency, false}]),

		{ok, #state{partition=Partition, table_id=TableId}}.

We then need to add two new clauses to the handle_command callback to handle
our two new commands, which translate almost directly to ets calls:

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

Before continuing think and if possible try to implement a delete function yourself.

Implementing Delete
-------------------

Here is the implementation of delete, in tanodb.erl we add a new function:

.. code-block:: erlang

	delete(Key) ->
		send_to_one(Key, {delete, Key}).

In tanodb_vnode.erl we add a new clause to handle_command:

.. code-block:: erlang

	handle_command({delete, Key}, _Sender,
				   State=#state{table_id=TableId, partition=Partition}) ->
		true = ets:delete(TableId, Key),
		{reply, {ok, Partition}, State};

