Quorum Requests
===============

How it Works
------------

Quorum requests allows sending a command to more than one vnode and wait until
a number of responses are received before considering the request succesful.

To implement this we need a process that distributed the requests to the first
N vnodes in the preference list and waits for at least W response to arrive
before returning to the requester.

We use a gen_fsm to implement this process, which looks like this::

    +------+    +---------+    +---------+    +---------+              +------+
    |      |    |         |    |         |    |         |remaining = 0 |      |
    | Init +--->| Prepare +--->| Execute +--->| Waiting +------------->| Stop |
    |      |    |         |    |         |    |         |              |      |
    +------+    +---------+    +---------+    +-------+-+              +------+
                                                  ^   | |                    
                                                  |   | |        +---------+ 
                                                  +---+ +------->|         | 
                                                                 | Timeout | 
                                          remaining > 0  timeout |         | 
                                                                 +---------+ 

Implementing it
---------------

To implement it we need to change the code in tanodb.erl instantiate a FSM
to handle the request instead of sending the command directly to one vnode.

.. code-block:: erlang

	get(Key) ->
		ReqId = make_ref(),
		Timeout = 5000,
		tanodb_write_fsm:get(?N, Key, self(), ReqId),
		wait_for_reqid(ReqId, Timeout).

	put(Key, Value) ->
		ReqId = make_ref(),
		Timeout = 5000,
		tanodb_write_fsm:put(?N, ?W, Key, Value, self(), ReqId),
		wait_for_reqid(ReqId, Timeout).

	delete(Key) ->
		ReqId = make_ref(),
		Timeout = 5000,
		tanodb_write_fsm:delete(?N, Key, self(), ReqId),
		wait_for_reqid(ReqId, Timeout).

To wait for the right answer we need to generate a unique identifier for each
request and send it with the request itself. The identifier will come back
in the message sent by the FSM once the request finishes.

If too much time passed waiting for the response we consider it an error and
return before receiving it.

.. code-block:: erlang

	wait_for_reqid(ReqId, Timeout) ->
		receive
			{ReqId, {error, Reason}} -> {error, Reason};
			{ReqId, Val} -> Val
		after
			Timeout -> {error, timeout}
		end.

On the vnode command handlers we need to receive the request id and return it
in the response:

.. code-block:: erlang

	handle_command({put, ReqId, Key, Value}, _Sender,
				   State=#state{table_id=TableId, partition=Partition}) ->
		ets:insert(TableId, {Key, Value}),
		Res = {ok, Partition},
		{reply, {ReqId, Res}, State};

	handle_command({get, ReqId, Key}, _Sender,
				   State=#state{table_id=TableId, partition=Partition}) ->
		Res = case ets:lookup(TableId, Key) of
				  [] ->
					  {not_found, Partition, Key};
				  [{_, Value}] ->
					  {found, Partition, {Key, Value}}
			  end,
		{reply, {ReqId, Res}, State};

	handle_command({delete, ReqId, Key}, _Sender,
				   State=#state{table_id=TableId, partition=Partition}) ->
		true = ets:delete(TableId, Key),
		Res = {ok, Partition},
		{reply, {ReqId, Res}, State};

Two new files are created:

tanodb_write_fsm.erl
    The FSM logic
tanodb_write_fsm_sup.erl
    The supervisor for the FSMs

Finally we need to add tanodb_write_fsm_sup to our top level supervisor in
tanodb_sup.

Testing it
----------

To test it we are going to run some calls to the API and observe that now
the response contains more than one response:

.. code-block:: erlang

	(tanodb@127.0.0.1)1> K1 = {ns, k1}.
	{ns,k1}

	(tanodb@127.0.0.1)2> V1 = v1.
	v1

	(tanodb@127.0.0.1)3> tanodb:get(K1).
	{ok,[{not_found,319703483166135013357056057156686910549735243776,
					{ns,k1}},
		 {not_found,296867520082839655260123481645494988367611297792,
					{ns,k1}},
		 {not_found,274031556999544297163190906134303066185487351808,
					{ns,k1}}]}

	(tanodb@127.0.0.1)4> tanodb:delete(K1).
	{ok,[{ok,319703483166135013357056057156686910549735243776},
		 {ok,296867520082839655260123481645494988367611297792},
		 {ok,274031556999544297163190906134303066185487351808}]}

	(tanodb@127.0.0.1)5> tanodb:put(K1, V1).
	{ok,[{ok,319703483166135013357056057156686910549735243776},
		 {ok,296867520082839655260123481645494988367611297792},
		 {ok,274031556999544297163190906134303066185487351808}]}

	(tanodb@127.0.0.1)6> tanodb:get(K1).
	{ok,[{found,296867520082839655260123481645494988367611297792,
				{{ns,k1},v1}},
		 {found,319703483166135013357056057156686910549735243776,
				{{ns,k1},v1}},
		 {found,274031556999544297163190906134303066185487351808,
				{{ns,k1},v1}}]}

	(tanodb@127.0.0.1)7> tanodb:delete(K1).
	{ok,[{ok,319703483166135013357056057156686910549735243776},
		 {ok,296867520082839655260123481645494988367611297792},
		 {ok,274031556999544297163190906134303066185487351808}]}

	(tanodb@127.0.0.1)8> tanodb:get(K1).
	{ok,[{not_found,319703483166135013357056057156686910549735243776,
					{ns,k1}},
		 {not_found,274031556999544297163190906134303066185487351808,
					{ns,k1}},
		 {not_found,296867520082839655260123481645494988367611297792,
					{ns,k1}}]}

