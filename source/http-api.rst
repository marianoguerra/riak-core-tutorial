HTTP API
========

How it Works
------------

We are adding a simple HTTP API to our system, it will run on all nodes and
allow us to interact with it from the outside.

We will use the Cowboy 2.0 HTTP Server.

Implementing it
---------------

We need to add cowboy as a dependency on rebar.config and tanodb.app.src.

Then in tanodb_app.erl we need to start the HTTP API:

.. code-block:: erlang

    setup_http_api() ->
      Dispatch = cowboy_router:compile([{'_', [{"/kv/:bucket/:key", tanodb_h_kv, []}]}]),
      
      HttpPort = application:get_env(tanodb, http_port, 8080),
      HttpAcceptors = application:get_env(tanodb, http_acceptors, 100),
      HttpMaxConnections = application:get_env(tanodb, http_max_connections, infinity),

      lager:info("Starting HTTP API at port ~p", [HttpPort]),

      {ok, _} = cowboy:start_clear(tanodb_http_listener,
        [{port, HttpPort},
         {num_acceptors, HttpAcceptors},
         {max_connections, HttpMaxConnections}],
        #{env => #{dispatch => Dispatch}}),

      ok.

We get the configuration from the environment, which is set by cuttlefish.

The API handler module tanodb_h_kv's main code:

.. code-block:: erlang

    init(ReqIn=#{method := <<"GET">>}, State) ->
        {Bucket, Key} = bindings(ReqIn),
        reply(ReqIn, State, tanodb:get(Bucket, Key));
    init(ReqIn=#{method := <<"POST">>}, State) ->
        {Bucket, Key} = bindings(ReqIn),
        {ok, Value, Req1} = read_all_body(ReqIn),
        reply(Req1, State, tanodb:put(Bucket, Key, Value));
    init(ReqIn=#{method := <<"DELETE">>}, State) ->
        {Bucket, Key} = bindings(ReqIn),
        reply(ReqIn, State, tanodb:delete(Bucket, Key)).

Trying it
---------

Single Node
...........

We are going to first test it on a single node.

Get key `k1` in bucket `b1`, which doesn't exist yet:

.. code-block:: sh

    curl -X GET  http://localhost:8098/kv/b1/k1

.. code-block:: javascript

    {
      "replies": [
        {
          "bucket": "b1",
          "error": "not_found",
          "key": "k1",
          "node": "tanodb@127.0.0.1",
          "ok": false,
          "partition": "1301649895747835411525156804137939564381064921088"
        },
        {
          "bucket": "b1",
          "error": "not_found",
          "key": "k1",
          "node": "tanodb@127.0.0.1",
          "ok": false,
          "partition": "1278813932664540053428224228626747642198940975104"
        },
        {
          "bucket": "b1",
          "error": "not_found",
          "key": "k1",
          "node": "tanodb@127.0.0.1",
          "ok": false,
          "partition": "1255977969581244695331291653115555720016817029120"
        }
      ]
    }

Put key `k1` in bucket `b1` with content `hi there`:

.. code-block:: sh

    curl -X POST  http://localhost:8098/kv/b1/k1 -d 'hi there'

.. code-block:: javascript

    {
      "replies": [
        {
          "node": "tanodb@127.0.0.1",
          "ok": true,
          "partition": "1301649895747835411525156804137939564381064921088"
        },
        {
          "node": "tanodb@127.0.0.1",
          "ok": true,
          "partition": "1278813932664540053428224228626747642198940975104"
        },
        {
          "node": "tanodb@127.0.0.1",
          "ok": true,
          "partition": "1255977969581244695331291653115555720016817029120"
        }
      ]
    }	

Get key `k1` in bucket `b1`, which now exists:

.. code-block:: sh

    curl -X GET  http://localhost:8098/kv/b1/k1

.. code-block:: javascript

    {
      "replies": [
        {
          "bucket": "b1",
          "key": "k1",
          "node": "tanodb@127.0.0.1",
          "ok": true,
          "partition": "1301649895747835411525156804137939564381064921088",
          "value": "hi there"
        },
        {
          "bucket": "b1",
          "key": "k1",
          "node": "tanodb@127.0.0.1",
          "ok": true,
          "partition": "1278813932664540053428224228626747642198940975104",
          "value": "hi there"
        },
        {
          "bucket": "b1",
          "key": "k1",
          "node": "tanodb@127.0.0.1",
          "ok": true,
          "partition": "1255977969581244695331291653115555720016817029120",
          "value": "hi there"
        }
      ]
    }	

Delete key `k1` in bucket `b1`:

.. code-block:: sh

    curl -X DELETE  http://localhost:8098/kv/b1/k1

.. code-block:: javascript

    {
      "replies": [
        {
          "node": "tanodb@127.0.0.1",
          "ok": true,
          "partition": "1301649895747835411525156804137939564381064921088"
        },
        {
          "node": "tanodb@127.0.0.1",
          "ok": true,
          "partition": "1278813932664540053428224228626747642198940975104"
        },
        {
          "node": "tanodb@127.0.0.1",
          "ok": true,
          "partition": "1255977969581244695331291653115555720016817029120"
        }
      ]
    }	

Get key `k1` in bucket `b1`, which shouldn't exist anymore:

.. code-block:: sh

    curl -X GET  http://localhost:8098/kv/b1/k1

.. code-block:: javascript

    {
      "replies": [
        {
          "bucket": "b1",
          "error": "not_found",
          "key": "k1",
          "node": "tanodb@127.0.0.1",
          "ok": false,
          "partition": "1301649895747835411525156804137939564381064921088"
        },
        {
          "bucket": "b1",
          "error": "not_found",
          "key": "k1",
          "node": "tanodb@127.0.0.1",
          "ok": false,
          "partition": "1278813932664540053428224228626747642198940975104"
        },
        {
          "bucket": "b1",
          "error": "not_found",
          "key": "k1",
          "node": "tanodb@127.0.0.1",
          "ok": false,
          "partition": "1255977969581244695331291653115555720016817029120"
        }
      ]
    }	

Cluster
.......

We are going to test it on a cluster now, notice that the port changes, we
are sending each request to a different node.

You can see each node's port on the logs at startup::

	[info] Starting HTTP API at port 8198

Get key `k1` in bucket `b1`, which doesn't exist yet:

.. code-block:: sh

    curl -X GET  http://localhost:8198/kv/b1/k1

Notice the node name on the partition field, it may change for you depending
on the state of handoff or how vnodes were distributed.

.. code-block:: javascript

    {
      "replies": [
        {
          "bucket": "b1",
          "error": "not_found",
          "key": "k1",
          "node": "tanodb2@127.0.0.1",
          "ok": false,
          "partition": "1301649895747835411525156804137939564381064921088"
        },
        {
          "bucket": "b1",
          "error": "not_found",
          "key": "k1",
          "node": "tanodb1@127.0.0.1",
          "ok": false,
          "partition": "1278813932664540053428224228626747642198940975104"
        },
        {
          "bucket": "b1",
          "error": "not_found",
          "key": "k1",
          "node": "tanodb1@127.0.0.1",
          "ok": false,
          "partition": "1255977969581244695331291653115555720016817029120"
        }
      ]
    }	

Put key `k1` in bucket `b1` with content `hi there`:

.. code-block:: sh

    curl -X POST  http://localhost:8298/kv/b1/k1 -d 'hi there'

.. code-block:: javascript

    {
      "replies": [
        {
          "node": "tanodb1@127.0.0.1",
          "ok": true,
          "partition": "1255977969581244695331291653115555720016817029120"
        },
        {
          "node": "tanodb1@127.0.0.1",
          "ok": true,
          "partition": "1278813932664540053428224228626747642198940975104"
        },
        {
          "node": "tanodb2@127.0.0.1",
          "ok": true,
          "partition": "1301649895747835411525156804137939564381064921088"
        }
      ]
    }	

Get key `k1` in bucket `b1`, which now exists:

.. code-block:: sh

    curl -X GET  http://localhost:8398/kv/b1/k1

.. code-block:: javascript

    {
      "replies": [
        {
          "bucket": "b1",
          "key": "k1",
          "node": "tanodb1@127.0.0.1",
          "ok": true,
          "partition": "1278813932664540053428224228626747642198940975104",
          "value": "hi there"
        },
        {
          "bucket": "b1",
          "key": "k1",
          "node": "tanodb1@127.0.0.1",
          "ok": true,
          "partition": "1255977969581244695331291653115555720016817029120",
          "value": "hi there"
        },
        {
          "bucket": "b1",
          "key": "k1",
          "node": "tanodb2@127.0.0.1",
          "ok": true,
          "partition": "1301649895747835411525156804137939564381064921088",
          "value": "hi there"
        }
      ]
    }	


Delete key `k1` in bucket `b1`:

.. code-block:: sh

    curl -X DELETE  http://localhost:8198/kv/b1/k1

.. code-block:: javascript

    {
      "replies": [
        {
          "node": "tanodb2@127.0.0.1",
          "ok": true,
          "partition": "1301649895747835411525156804137939564381064921088"
        },
        {
          "node": "tanodb1@127.0.0.1",
          "ok": true,
          "partition": "1278813932664540053428224228626747642198940975104"
        },
        {
          "node": "tanodb1@127.0.0.1",
          "ok": true,
          "partition": "1255977969581244695331291653115555720016817029120"
        }
      ]
    }	

Get key `k1` in bucket `b1`, which shouldn't exist anymore:

.. code-block:: sh

    curl -X GET  http://localhost:8298/kv/b1/k1

.. code-block:: javascript

    {
      "replies": [
        {
          "bucket": "b1",
          "error": "not_found",
          "key": "k1",
          "node": "tanodb1@127.0.0.1",
          "ok": false,
          "partition": "1278813932664540053428224228626747642198940975104"
        },
        {
          "bucket": "b1",
          "error": "not_found",
          "key": "k1",
          "node": "tanodb1@127.0.0.1",
          "ok": false,
          "partition": "1255977969581244695331291653115555720016817029120"
        },
        {
          "bucket": "b1",
          "error": "not_found",
          "key": "k1",
          "node": "tanodb2@127.0.0.1",
          "ok": false,
          "partition": "1301649895747835411525156804137939564381064921088"
        }
      ]
    }	

