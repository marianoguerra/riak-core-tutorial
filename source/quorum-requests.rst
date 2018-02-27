Quorum Requests
===============

How it Works
------------

Here is a diagram of how it works::

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

tanodb.erl

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

.. code-block:: erlang

	wait_for_reqid(ReqId, Timeout) ->
		receive
			{ReqId, {error, Reason}} -> {error, Reason};
			{ReqId, Val} -> Val
		after
			Timeout -> {error, timeout}
		end.

tanodb_vnode.erl

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

tanodb_write_fsm.erl and tanodb_write_fsm_sup.erl

Add tanodb_write_fsm_sup to tanodb_sup


Testing it
----------

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

