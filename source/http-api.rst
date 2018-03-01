HTTP API
========

Testing It
----------

.. code-block:: sh

    curl -X GET  http://localhost:8080/kv/b1/k1

.. code-block:: javascript

    {
        "replies": [
            {
                "bucket": "b1",
                "error": "not_found",
                "key": "k1",
                "ok": false,
                "partition": 1301649895747835411525156804137939564381064921088
            },
            {
                "bucket": "b1",
                "error": "not_found",
                "key": "k1",
                "ok": false,
                "partition": 1278813932664540053428224228626747642198940975104
            },
            {
                "bucket": "b1",
                "error": "not_found",
                "key": "k1",
                "ok": false,
                "partition": 1255977969581244695331291653115555720016817029120
            }
        ]
    }

.. code-block:: sh

    curl -X POST  http://localhost:8080/kv/b1/k1 -d 'hi there'

.. code-block:: javascript

    {
        "replies": [
            {
                "ok": true,
                "partition": 1301649895747835411525156804137939564381064921088
            },
            {
                "ok": true,
                "partition": 1278813932664540053428224228626747642198940975104
            },
            {
                "ok": true,
                "partition": 1255977969581244695331291653115555720016817029120
            }
        ]
    }

.. code-block:: sh

    curl -X GET  http://localhost:8080/kv/b1/k1

.. code-block:: javascript

    {
        "replies": [
            {
                "bucket": "b1",
                "key": "k1",
                "ok": true,
                "partition": 1301649895747835411525156804137939564381064921088,
                "value": "hi there"
            },
            {
                "bucket": "b1",
                "key": "k1",
                "ok": true,
                "partition": 1278813932664540053428224228626747642198940975104,
                "value": "hi there"
            },
            {
                "bucket": "b1",
                "key": "k1",
                "ok": true,
                "partition": 1255977969581244695331291653115555720016817029120,
                "value": "hi there"
            }
        ]
    }

.. code-block:: sh

    curl -X DELETE  http://localhost:8080/kv/b1/k1

.. code-block:: javascript

    {
        "replies": [
            {
                "ok": true,
                "partition": 1301649895747835411525156804137939564381064921088
            },
            {
                "ok": true,
                "partition": 1278813932664540053428224228626747642198940975104
            },
            {
                "ok": true,
                "partition": 1255977969581244695331291653115555720016817029120
            }
        ]
    }

.. code-block:: sh

    curl -X GET  http://localhost:8080/kv/b1/k1

.. code-block:: javascript

    {
        "replies": [
            {
                "bucket": "b1",
                "error": "not_found",
                "key": "k1",
                "ok": false,
                "partition": 1301649895747835411525156804137939564381064921088
            },
            {
                "bucket": "b1",
                "error": "not_found",
                "key": "k1",
                "ok": false,
                "partition": 1255977969581244695331291653115555720016817029120
            },
            {
                "bucket": "b1",
                "error": "not_found",
                "key": "k1",
                "ok": false,
                "partition": 1278813932664540053428224228626747642198940975104
            }
        ]
    }
