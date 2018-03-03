First Commands
==============

Implementing Get, Put and Delete
--------------------------------

For our first commands we will copy the general structure of the ping command.

We will start by adding three new functions to the tanodb.erl file:

.. code-block:: erlang

    get(Bucket, Key) ->
        ReqId = make_ref(),
        send_to_one(Bucket, Key, {get, ReqId, {Bucket, Key}}).

    put(Bucket, Key, Value) ->
        ReqId = make_ref(),
        send_to_one(Bucket, Key, {put, ReqId, {Bucket, Key, Value}}).

    delete(Bucket, Key) ->
        ReqId = make_ref(),
        send_to_one(Bucket, Key, {delete, ReqId, {Bucket, Key}}).

And generalizing the code used by ping to send a command to one vnode:

.. code-block:: erlang

    send_to_one(Bucket, Key, Cmd) ->
        DocIdx = riak_core_util:chash_key({Bucket, Key}),
        PrefList = riak_core_apl:get_primary_apl(DocIdx, 1, tanodb),
        [{IndexNode, _Type}] = PrefList,
        riak_core_vnode_master:sync_spawn_command(IndexNode, Cmd, tanodb_vnode_master).


In tanodb_vnode.erl we will need to first create an instance of the key-value
store per vnode at initialization and keep a reference to its state in the
vnode state record:

.. code-block:: erlang

    -record(state, {partition, kv_state}).

    init([Partition]) ->
        {ok, KvState} = tanodb_kv_ets:new(#{partition => Partition}),
        {ok, #state { partition=Partition, kv_state=KvState }}.

We then need to add three new clauses to the handle_command callback to handle
our two new commands, which translate almost directly to calls in the kv module:

.. code-block:: erlang

    handle_command({put, ReqId, {Bucket, Key, Value}}, _Sender,
                   State=#state{kv_state=KvState, partition=Partition}) ->
        Location = [Partition, node()],
        {Res, KvState1} = tanodb_kv_ets:put(KvState, Bucket, Key, Value),
        {reply, {ReqId, {Location, Res}}, State#state{kv_state=KvState1}};

    handle_command({get, ReqId, {Bucket, Key}}, _Sender,
                   State=#state{kv_state=KvState, partition=Partition}) ->
        Location = [Partition, node()],
        {Res, KvState1} = tanodb_kv_ets:get(KvState, Bucket, Key),
        {reply, {ReqId, {Location, Res}}, State#state{kv_state=KvState1}};

    handle_command({delete, ReqId, {Bucket, Key}}, _Sender,
                   State=#state{kv_state=KvState, partition=Partition}) ->
        Location = [Partition, node()],
        {Res, KvState1} = tanodb_kv_ets:delete(KvState, Bucket, Key),
        {reply, {ReqId, {Location, Res}}, State#state{kv_state=KvState1}};

Trying it
---------

First let's try to get a key that doesn't exist:

.. code-block:: erlang

    (tanodb@127.0.0.1)1> B1 = b1.
    (tanodb@127.0.0.1)2> K1 = k1.
    (tanodb@127.0.0.1)3> V1 = v1.

.. code-block:: erlang

    (tanodb@127.0.0.1)4> tanodb:get(B1, K1).

.. code-block:: erlang

    {Ref, {[1050454301831586472458898473514828420377701515264,
            'tanodb@127.0.0.1'],
      {not_found,{b1,k1}}}}

The structure of the response is:

.. code-block:: erlang

    {UniqueRequestReference, {[PartitionId, NodeId], CommandResponse}}.

Let's try deleting a key that doesn't exist:

.. code-block:: erlang

    (tanodb@127.0.0.1)5> tanodb:delete(B1, K1).

.. code-block:: erlang

    {Ref, {[1050454301831586472458898473514828420377701515264,
            'tanodb@127.0.0.1'],
      ok}}

Let's put a value:

.. code-block:: erlang

    (tanodb@127.0.0.1)6> tanodb:put(B1, K1, V1).

.. code-block:: erlang

    {Ref, {[1050454301831586472458898473514828420377701515264,
            'tanodb@127.0.0.1'],
      ok}}

Now let's get the value:

.. code-block:: erlang

    (tanodb@127.0.0.1)7> tanodb:get(B1, K1).

.. code-block:: erlang

    {Ref, {[1050454301831586472458898473514828420377701515264,
            'tanodb@127.0.0.1'],
      {found,{{b1,k1},v1}}}}

Let's delete it:

.. code-block:: erlang

    (tanodb@127.0.0.1)8> tanodb:delete(B1, K1).

.. code-block:: erlang

    {Ref, {[1050454301831586472458898473514828420377701515264,
            'tanodb@127.0.0.1'],
      ok}}

And try to get it back:

.. code-block:: erlang

    (tanodb@127.0.0.1)9> tanodb:get(B1, K1).

.. code-block:: erlang

    {Ref, {[1050454301831586472458898473514828420377701515264,
            'tanodb@127.0.0.1'],
      {not_found,{b1,k1}}}}

