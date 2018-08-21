Coverage Calls
==============

.. note::

    The content of this chapter is in the `05-coverage` branch.

    https://gitlab.com/marianoguerra/tanodb/tree/05-coverage

How it Works
------------

Since bucket and key are hashed together to decide to which vnode a request
will go it means that the keys for a given bucket may be distributed in
multiple vnodes, and in case you are running in a cluster this means your keys
are distributed in multiple physical nodes.

This means that to list all the keys from a bucket we have to ask all the
vnodes for the keys on a given bucket and then put the responses together and
return the set of all responses.

For this Riak Core provides something called coverage calls, which are a way to
handle this process of running a command on all vnodes and gathering the
responses.

In this chapter we are going to implement the `tanodb:keys(Bucket)` function
using coverage calls.

In this case we call `tanodb_coverage_fsm:start({keys, Bucket}, Timeout)`, which
is a new module, it implements a behavior called `riak_core_coverage_fsm`, short
for riak_core_coverage `finite state machine <https://en.wikipedia.org/wiki/Finite-state_machine>`_,
it implements some predefined callbacks that are called on different states of
a finite state machine.

The start function calls `tanodb_coverage_fsm_sup:start_fsm([ReqId, self(), Request, Timeout])`
which starts a supervisor for this new process.

When we start the fsm with a command `{keys, Bucket}` and a timeout in
milliseconds, it starts a supervisor that starts the finite state machine
process, it first calls the init function which initializes the state of the
process and returns some information to riak_core so it knows what kind of
coverage call we want to do, then riak_core calls the handle_coverage function
on each vnode and with each response it calls `process_result` in our process.

When all the results are received or if an error happens (such as a timeout) it
will call the finish callback there we send the results to the calling process
which is waiting for it.

The handle_coverage implementation is really simple, it uses the
`ets:match/2 function <http://www.erlang.org/doc/man/ets.html#match-2>`_ to
match against all the entries with the given bucket and returns the key from
the matched results.

You can read more about ets match specs in the
`match spec chapter on the Erlang documentation <http://www.erlang.org/doc/apps/erts/match_spec.html>`_.

Implementing it
---------------

Code in tanodb.erl is really simple:

.. code-block:: erlang

    keys(Bucket, Opts) ->
        Timeout = maps:get(timeout, Opts, ?TIMEOUT),
        tanodb_coverage_fsm:start({keys, Bucket}, Timeout).


In tanodb_vnode.erl we need to implement the handle_coverage callback:

.. code-block:: erlang

    handle_coverage({keys, Bucket}, _KeySpaces, {_, RefId, _},
                    State=#state{kv_state=KvState}) ->
        {Keys, KvState1} = tanodb_kv_ets:keys(KvState, Bucket),
        {reply, {RefId, Keys}, State#state{kv_state=KvState1}};

We add two new modules: 

tanodb_coverage_fsm
    The FSM implementation for the coverage call.
tanodb_coverage_fsm_sup
    The supervisor for the FSM processes.

We also add the tanodb_coverage_fsm_sup to the tanodb_sup supervisor tree.

Trying it
---------

.. code-block:: erlang

	Nums = lists:seq(1, 10).
	Buckets = lists:map(fun (N) -> list_to_binary("bucket-" ++ integer_to_list(N)) end,
	Nums).
	Keys = lists:map(fun (N) -> list_to_binary("key-" ++ integer_to_list(N)) end, Nums).

	GenValue = fun (Bucket, Key) -> [{bucket, Bucket}, {key, Key}] end.

	lists:foreach(fun (Bucket) ->
		lists:foreach(fun (Key) ->
			Val = GenValue(Bucket, Key),
			tanodb:put(Bucket, Key, Val)
		end, Keys)
	end, Buckets).

	{ok, Items} = tanodb:keys(<<"bucket-1">>).
	[{Partition, Node, Keys} || {Partition, Node, Keys} <- Items, Keys =/= []]. 

.. code-block:: erlang

	[{296867520082839655260123481645494988367611297792,
	  'tanodb@127.0.0.1', [<<"key-10">>]},
	 {365375409332725729550921208179070754913983135744,
	  'tanodb@127.0.0.1', [<<"key-4">>]},
	 {137015778499772148581595453067151533092743675904,
	  'tanodb@127.0.0.1', [<<"key-8">>]},
	 {707914855582156101004909840846949587645842325504,
	  'tanodb@127.0.0.1', [<<"key-9">>]},
	 {45671926166590716193865151022383844364247891968,
	  'tanodb@127.0.0.1', [<<"key-2">>]},
	 {753586781748746817198774991869333432010090217472,
	  'tanodb@127.0.0.1', [<<"key-9">>]},
	 {274031556999544297163190906134303066185487351808,
	  'tanodb@127.0.0.1', [<<"key-10">>]},
	 {822094670998632891489572718402909198556462055424,
	  'tanodb@127.0.0.1', [<<"key-5">>]},
	 {319703483166135013357056057156686910549735243776,
	  'tanodb@127.0.0.1', [<<"key-4">>,<<"key-10">>]},
	 {342539446249430371453988632667878832731859189760,
	  'tanodb@127.0.0.1', [<<"key-4">>]},
	 {68507889249886074290797726533575766546371837952,
	  'tanodb@127.0.0.1', [<<"key-2">>]},
	 {799258707915337533392640142891717276374338109440,
	  'tanodb@127.0.0.1', [<<"key-5">>]},
	 {91343852333181432387730302044767688728495783936,
	  'tanodb@127.0.0.1', [<<"key-2">>]},
	 {730750818665451459101842416358141509827966271488,
	  'tanodb@127.0.0.1', [<<"key-9">>]},
	 {159851741583067506678528028578343455274867621888,
	  'tanodb@127.0.0.1', [<<"key-8">>]},
	 {182687704666362864775460604089535377456991567872,
	  'tanodb@127.0.0.1', [<<"key-8">>]},
	 {844930634081928249586505293914101120738586001408,
	  'tanodb@127.0.0.1', [<<"key-5">>]},
	 {867766597165223607683437869425293042920709947392,
	  'tanodb@127.0.0.1', [<<"key-3">>]},
	 {890602560248518965780370444936484965102833893376,
	  'tanodb@127.0.0.1', [<<"key-3">>]},
	 {1050454301831586472458898473514828420377701515264,
	  'tanodb@127.0.0.1', [<<"key-6">>]},
	 {913438523331814323877303020447676887284957839360,
	  'tanodb@127.0.0.1', [<<"key-3">>]},
	 {1118962191081472546749696200048404186924073353216,
	  'tanodb@127.0.0.1', [<<"key-7">>,<<"key-1">>]},
	 {1164634117248063262943561351070788031288321245184,
	  'tanodb@127.0.0.1', [<<"key-7">>]},
	 {1027618338748291114361965898003636498195577569280,
	  'tanodb@127.0.0.1', [<<"key-"...>>]},
	 {1096126227998177188652763624537212264741949407232,
	  'tanodb@127.0.0.1', [<<...>>]},
	 {1073290264914881830555831049026020342559825461248,
	  'tanodb@127.0.0.1', [...]},
	 {1141798154164767904846628775559596109106197299200,
	  'tanodb@127.0.0.1',...}]
