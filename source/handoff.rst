Handoff
=======

How it Works
------------

With quorum requests we are halfway in our way to tolerate failures in cluster
nodes, our values are written to more than one vnode but if a node dies and
another takes his work or if we add a new node and the vnodes must be
rebalanced we need to handle `handoff <https://github.com/basho/riak_core/wiki/Handoffs>`_.

The reasons to start a handoff are:

* A ring update event for a ring that all other nodes have already seen.
* A secondary vnode is idle for a period of time and the primary, original
  owner of the partition is up again.

When this happens riak_core will inform the vnode that handoff is starting,
calling `handoff_starting`, if it returns false it's cancelled, if it returns
true it calls `is_empty`, that must return false to inform that the vnode has
something to handoff (it's not empty) or true to inform that the vnode is
empty, in our case we ask for the first element of the ets table and if it's
the special value '$end_of_table' we know it's empty, if it returns true the
handoff is considered finished, if false then a call is done to `handle_handoff_command`
passing as first parameter an opaque structure that contains two fields we are
insterested in, foldfun and acc0, they can be unpacked with a macro like this:

.. code-block:: erlang

    handle_handoff_command(?FOLD_REQ{foldfun=Fun, acc0=Acc0}, _Sender, State) ->

The `FOLD_REQ` macro is defined in the riak_core_vnode.hrl header file which we
include.

This function must iterate through all the keys it stores and for each of them
call foldfun with the key as first argument, the value as second argument and
the latest acc0 value as third.

The result of the function call is the new `Acc0` you must pass to the next
call to foldfun, the last `Acc0` must be returned by the handle_handoff_command.

For each call to `Fun(Key, Entry, AccIn0)` riak_core will send it to the new
vnode, to do that it must encode the data before sending, it does this by
calling `encode_handoff_item(Key, Value)`, where you must encode the data
before sending it.

When the value is received by the new vnode it must decode it and do something
with it, this is done by the function `handle_handoff_data`, where we decode the
received data and do the appropriate thing with it.

When we sent all the key/values `handoff_finished` will be called and then
`delete` so we cleanup the data on the old vnode .

You can decide to handle other commands sent to the vnode while the handoff is
running, you can choose to do one of the followings:

* Handle it in the current vnode
* Forward it to the vnode we are handing off
* Drop it

What to do depends on the design of you app, all of them have tradeoffs.

The signature of all the responses is:

.. code:: erlang

    -callback handle_handoff_command(Request::term(), Sender::sender(), ModState::term()) ->
    {reply, Reply::term(), NewModState::term()} |
    {noreply, NewModState::term()} |
    {async, Work::function(), From::sender(), NewModState::term()} |
    {forward, NewModState::term()} |
    {drop, NewModState::term()} |
    {stop, Reason::term(), NewModState::term()}.

A diagram of the flow is as follows::

     +-----------+      +----------+        +----------+                
     |           | true |          | false  |          |                
     | Starting  +------> is_empty +--------> fold_req |                
     |           |      |          |        |          |                
     +-----+-----+      +----+-----+        +----+-----+                
           |                 |                   |                      
           | false           | true              | ok                   
           |                 |                   |                      
     +-----v-----+           |              +----v-----+     +--------+ 
     |           |           |              |          |     |        | 
     | Cancelled |           +--------------> finished +-----> delete | 
     |           |                          |          |     |        | 
     +-----------+                          +----------+     +--------+ 

Implementing it
---------------

We need to add logic to all the empty callbacks related to handoff:

.. code-block:: erlang

    handle_handoff_command(?FOLD_REQ{foldfun=FoldFun, acc0=Acc0}, _Sender,
                           State=#state{partition=Partition, kv_state=KvState}) ->
        lager:info("fold req ~p", [Partition]),
        KvFoldFun = fun ({Key, Val}, AccIn) ->
                            lager:info("fold fun ~p: ~p", [Key, Val]),
                            FoldFun(Key, Val, AccIn)
                    end,
        {AccFinal, KvState1} = tanodb_kv_ets:foldl(KvFoldFun, Acc0, KvState),
        {reply, AccFinal, State#state{kv_state=KvState1}};

    handle_handoff_command(Message, _Sender, State) ->
        lager:warning("handoff command ~p, ignoring", [Message]),
        {noreply, State}.

    handoff_starting(TargetNode, State=#state{partition=Partition}) ->
        lager:info("handoff starting ~p: ~p", [Partition, TargetNode]),
        {true, State}.

    handoff_cancelled(State=#state{partition=Partition}) ->
        lager:info("handoff cancelled ~p", [Partition]),
        {ok, State}.

    handoff_finished(TargetNode, State=#state{partition=Partition}) ->
        lager:info("handoff finished ~p: ~p", [Partition, TargetNode]),
        {ok, State}.

    handle_handoff_data(BinData, State=#state{kv_state=KvState}) ->
        TermData = binary_to_term(BinData),
        lager:info("handoff data received ~p", [TermData]),
        {{Bucket, Key}, Value} = TermData,
        {ok, KvState1} = tanodb_kv_ets:put(KvState, Bucket, Key, Value),
        {reply, ok, State#state{kv_state=KvState1}}.

    encode_handoff_item(Key, Value) ->
        term_to_binary({Key, Value}).

    is_empty(State=#state{kv_state=KvState, partition=Partition}) ->
        {IsEmpty, KvState1} = tanodb_kv_ets:is_empty(KvState),
        lager:info("is_empty ~p: ~p", [Partition, IsEmpty]),
        {IsEmpty, State#state{kv_state=KvState1}}.

    delete(State=#state{kv_state=KvState, partition=Partition}) ->
        lager:info("delete ~p", [Partition]),
        {ok, KvState1} = tanodb_kv_ets:dispose(KvState),
        {ok, KvState2} = tanodb_kv_ets:delete(KvState1),
        {ok, State#state{kv_state=KvState2}}.

Trying it
---------

To test it we will first start a devrel node, put some values and then join
two other nodes and see on the console the handoff happening.

To make sure the nodes don't know about each other in case you played with
clustering already we will start by removing the devrel builds:

.. code-block:: sh

    rm -rf _build/dev*

And build the nodes again:

.. code-block:: sh

    make devrel

Now we will start the first node and connect to its console:

.. code-block:: sh

    make dev1-console

We generate a list of some numbers:

.. code-block:: erlang

    (tanodb1@127.0.0.1)1> Nums = lists:seq(1, 10).

    [1,2,3,4,5,6,7,8,9,10]

And with it create some bucket names:

.. code-block:: erlang

    (tanodb1@127.0.0.1)2>
    Buckets = lists:map(fun (N) ->
        list_to_binary("bucket-" ++ integer_to_list(N))
    end, Nums).

    [<<"bucket-1">>,<<"bucket-2">>,<<"bucket-3">>,
     <<"bucket-4">>,<<"bucket-5">>,<<"bucket-6">>,<<"bucket-7">>,
     <<"bucket-8">>,<<"bucket-9">>,<<"bucket-10">>]

And some key names:

.. code-block:: erlang

    (tanodb1@127.0.0.1)3>
    Keys = lists:map(fun (N) ->
        list_to_binary("key-" ++ integer_to_list(N))
    end, Nums).

    [<<"key-1">>,<<"key-2">>,<<"key-3">>,<<"key-4">>,
     <<"key-5">>,<<"key-6">>,<<"key-7">>,<<"key-8">>,<<"key-9">>,
     <<"key-10">>]

We create a function to generate a value from a bucket and a key:

.. code-block:: erlang

    (tanodb1@127.0.0.1)4>
    GenValue = fun (Bucket, Key) -> [{bucket, Bucket}, {key, Key}] end.

And then put some values to the buckets and keys we created:

.. code-block:: erlang

    (tanodb1@127.0.0.1)5>
    lists:foreach(fun (Bucket) ->
        lists:foreach(fun (Key) ->
            Val = GenValue(Bucket, Key),
            tanodb:put(Bucket, Key, Val)
        end, Keys)
    end, Buckets).

    ok

Now that we have some data let's start the other two nodes:

.. code-block:: sh

    make dev2-console

In yet another shell:

.. code-block:: sh

    make dev3-console

This part should remind you of the first chapter:

.. code-block:: sh

    make devrel-join

::

    Success: staged join request for 'tanodb2@127.0.0.1' to 'tanodb1@127.0.0.1'
    Success: staged join request for 'tanodb3@127.0.0.1' to 'tanodb1@127.0.0.1'

.. code-block:: sh

    make devrel-cluster-plan

::

    =============================== Staged Changes =========================
    Action         Details(s)
    ------------------------------------------------------------------------
    join           'tanodb2@127.0.0.1'
    join           'tanodb3@127.0.0.1'
    ------------------------------------------------------------------------


    NOTE: Applying these changes will result in 1 cluster transition

    ########################################################################
                             After cluster transition 1/1
    ########################################################################

    ================================= Membership ===========================
    Status     Ring    Pending    Node
    ------------------------------------------------------------------------
    valid     100.0%     34.4%    'tanodb1@127.0.0.1'
    valid       0.0%     32.8%    'tanodb2@127.0.0.1'
    valid       0.0%     32.8%    'tanodb3@127.0.0.1'
    ------------------------------------------------------------------------
    Valid:3 / Leaving:0 / Exiting:0 / Joining:0 / Down:0

    WARNING: Not all replicas will be on distinct nodes

    Transfers resulting from cluster changes: 42
      21 transfers from 'tanodb1@127.0.0.1' to 'tanodb3@127.0.0.1'
      21 transfers from 'tanodb1@127.0.0.1' to 'tanodb2@127.0.0.1'

.. code-block:: sh

    make devrel-cluster-commit

::

    Cluster changes committed

On the consoles from the nodes you should see some logs like the following, I
will just paste some as example.

On the sending side::

    00:17:24.240 [info] Starting ownership transfer of tanodb_vnode from
    'tanodb1@127.0.0.1' 1118962191081472546749696200048404186924073353216 to
    'tanodb2@127.0.0.1' 1118962191081472546749696200048404186924073353216

    00:17:24.240 [info] fold req 1118962191081472546749696200048404186924073353216
    00:17:24.240 [info] fold fun {<<"bucket-1">>,<<"key-1">>}:
        [{bucket,<<"bucket-1">>},{key,<<"key-1">>}]

    ...

    00:17:24.241 [info] fold fun {<<"bucket-7">>,<<"key-8">>}:
        [{bucket,<<"bucket-7">>},{key,<<"key-8">>}]

    00:17:24.281 [info] ownership transfer of tanodb_vnode from
    'tanodb1@127.0.0.1' 1118962191081472546749696200048404186924073353216 to
    'tanodb2@127.0.0.1' 1118962191081472546749696200048404186924073353216
        completed: sent 575.00 B bytes in 7 of 7 objects in 0.04 seconds
        (13.67 KB/second)

    00:17:24.280 [info] handoff finished
        1141798154164767904846628775559596109106197299200:
        {1141798154164767904846628775559596109106197299200,
            'tanodb3@127.0.0.1'}

    00:17:24.285 [info] delete
        1141798154164767904846628775559596109106197299200

On the receiving side::

    00:13:59.641 [info] handoff starting
        1050454301831586472458898473514828420377701515264:
        {hinted,{1050454301831586472458898473514828420377701515264,
            'tanodb1@127.0.0.1'}}

    00:13:59.641 [info] is_empty
        182687704666362864775460604089535377456991567872: true

    00:14:34.259 [info] Receiving handoff data for partition
        tanodb_vnode:68507889249886074290797726533575766546371837952 from
        {"127.0.0.1",47440}

    00:14:34.296 [info] handoff data received
        {{<<"bucket-8">>,<<"key-1">>},
            [{bucket,<<"bucket-8">>},{key,<<"key-1">>}]}

    ...

    00:14:34.297 [info] handoff data received
        {{<<"bucket-3">>,<<"key-7">>},
            [{bucket,<<"bucket-3">>},{key,<<"key-7">>}]}

    00:14:34.298 [info] Handoff receiver for partition
        68507889249886074290797726533575766546371837952 exited after
        processing 5 objects from {"127.0.0.1",47440}

