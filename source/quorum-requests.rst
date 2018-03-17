Quorum Requests
===============

.. note::


    The content of this chapter is in the `03-quorum` branch.

    https://gitlab.com/marianoguerra/tanodb/tree/03-quorum

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

    get(Bucket, Key, Opts) ->
        K = {Bucket, Key},
        Params = K,
        run_quorum(get, K, Params, Opts).

    put(Bucket, Key, Value, Opts) ->
        K = {Bucket, Key},
        Params = {Bucket, Key, Value},
        run_quorum(put, K, Params, Opts).

    delete(Bucket, Key, Opts) ->
        K = {Bucket, Key},
        Params = K,
        run_quorum(delete, K, Params, Opts).

We are going to generalize that logic in a function called run_quorum, where
we can pass options for N, W and Timeout to play with different values:

.. code-block:: erlang

    run_quorum(Action, K, Params, Opts) ->
        N = maps:get(n, Opts, ?N),
        W = maps:get(w, Opts, ?W),
        Timeout = maps:get(timeout, Opts, ?TIMEOUT),
        ReqId = make_ref(),
        tanodb_write_fsm:run(Action, K, Params, N, W, self(), ReqId),
        wait_for_reqid(ReqId, Timeout).

    wait_for_reqid(ReqId, Timeout) ->
        receive
            {ReqId, Val} -> Val
        after
            Timeout -> {error, timeout}
        end.

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

There are two new files:

tanodb_write_fsm.erl
    The FSM logic
tanodb_write_fsm_sup.erl
    The supervisor for the FSMs

Finally we need to add tanodb_write_fsm_sup to our top level supervisor in
tanodb_sup.

Trying it
---------

To test it we are going to run some calls to the API and observe that now
the response contains more than one response:

.. code-block:: erlang

	(tanodb@127.0.0.1)1> B1 = b1.
	(tanodb@127.0.0.1)2> K1 = k1.
	(tanodb@127.0.0.1)3> V1 = v1.

First let's try to get a key that doesn't exist:

.. code-block:: erlang

	(tanodb@127.0.0.1)4> tanodb:get(B1, K1).

.. code-block:: erlang

	{ok,[{[1073290264914881830555831049026020342559825461248,
		   'tanodb@127.0.0.1'],
		  {not_found,{b1,k1}}},

		 {[1050454301831586472458898473514828420377701515264,
		   'tanodb@127.0.0.1'],
		  {not_found,{b1,k1}}},

		 {[1096126227998177188652763624537212264741949407232,
		   'tanodb@127.0.0.1'],
		  {not_found,{b1,k1}}}]}

Let's do the same call but passing options, we want to run the command in 5
vnodes and wait for the response of the 5, the request should finish under a
second:

.. code-block:: erlang

	(tanodb@127.0.0.1)5> tanodb:get(k1, v1, #{n => 5, w => 5, timeout => 1000}).

.. code-block:: erlang

	{ok,[{[456719261665907161938651510223838443642478919680,
		   'tanodb@127.0.0.1'],
		  {not_found,{k1,v1}}},

		 {[433883298582611803841718934712646521460354973696,
		   'tanodb@127.0.0.1'],
		  {not_found,{k1,v1}}},

		 {[411047335499316445744786359201454599278231027712,
		   'tanodb@127.0.0.1'],
		  {not_found,{k1,v1}}},

		 {[388211372416021087647853783690262677096107081728,
		   'tanodb@127.0.0.1'],
		  {not_found,{k1,v1}}},

		 {[365375409332725729550921208179070754913983135744,
		   'tanodb@127.0.0.1'],
		  {not_found,{k1,v1}}}]}

Let's try deleting a key that doesn't exist:

.. code-block:: erlang

	(tanodb@127.0.0.1)6> tanodb:delete(B1, K1).

.. code-block:: erlang

	{ok,[{[1050454301831586472458898473514828420377701515264,
		   'tanodb@127.0.0.1'],
		  ok},

		 {[1073290264914881830555831049026020342559825461248,
		   'tanodb@127.0.0.1'],
		  ok},

		 {[1096126227998177188652763624537212264741949407232,
		   'tanodb@127.0.0.1'],
		  ok}]}

Let's put a value:

.. code-block:: erlang

	(tanodb@127.0.0.1)7> tanodb:put(B1, K1, V1).

.. code-block:: erlang

	{ok,[{[1096126227998177188652763624537212264741949407232,
		   'tanodb@127.0.0.1'],
		  ok},

		 {[1073290264914881830555831049026020342559825461248,
		   'tanodb@127.0.0.1'],
		  ok},

		 {[1050454301831586472458898473514828420377701515264,
		   'tanodb@127.0.0.1'],
		  ok}]}

Now let's get the value:

.. code-block:: erlang

	(tanodb@127.0.0.1)8> tanodb:get(B1, K1).

.. code-block:: erlang

	{ok,[{[1096126227998177188652763624537212264741949407232,
		   'tanodb@127.0.0.1'],
		  {found,{{b1,k1},v1}}},

		 {[1050454301831586472458898473514828420377701515264,
		   'tanodb@127.0.0.1'],
		  {found,{{b1,k1},v1}}},

		 {[1073290264914881830555831049026020342559825461248,
		   'tanodb@127.0.0.1'],
		  {found,{{b1,k1},v1}}}]}

Let's delete it:

.. code-block:: erlang

	(tanodb@127.0.0.1)9> tanodb:delete(B1, K1).

.. code-block:: erlang

	{ok,[{[1073290264914881830555831049026020342559825461248,
		   'tanodb@127.0.0.1'],
		  ok},

		 {[1096126227998177188652763624537212264741949407232,
		   'tanodb@127.0.0.1'],
		  ok},

		 {[1050454301831586472458898473514828420377701515264,
		   'tanodb@127.0.0.1'],
		  ok}]}

And try to get it back:

.. code-block:: erlang

	(tanodb@127.0.0.1)10> tanodb:get(B1, K1).

.. code-block:: erlang

	{ok,[{[1073290264914881830555831049026020342559825461248,
		   'tanodb@127.0.0.1'],
		  {not_found,{b1,k1}}},

		 {[1096126227998177188652763624537212264741949407232,
		   'tanodb@127.0.0.1'],
		  {not_found,{b1,k1}}},

		 {[1050454301831586472458898473514828420377701515264,
		   'tanodb@127.0.0.1'],
		  {not_found,{b1,k1}}}]}

