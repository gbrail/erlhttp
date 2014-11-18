-module(erlhttp_test).
-compile([export_all]).

-include_lib("eunit/include/eunit.hrl").

% TODO Implement proper tests

% {ok,[done,
%      {header_value,<<"www.example.com">>},
%      {header_field,<<"Host">>},
%      {version,{1,1}},
%      {url,<<"/index.html">>},
%      {method,get}],
%     <<>>}
    
    
simple_test() ->
    {ok, Parser} = erlhttp:new(),
    Request = <<"GET /index.html HTTP/1.1\r\n",
                "Host: www.example.com\r\nFoo: bar\r\n\r\n">>,

    {ok, Remaining, Parser1} = erlhttp:update(Request, Parser),
    ?assertEqual(length(binary:bin_to_list(Remaining)), 0),

    {request, Result, Parser2} = erlhttp:parse(Parser1),
    ?assert(lists:any(fun(V) -> V =:= {url, <<"/index.html">>} end, Result)),
    ?assert(lists:any(fun(V) -> V =:= {method, get} end, Result)),
    ?assert(lists:any(fun(V) -> V =:= {version, {1, 1}} end, Result)),

    {headers, Result1, Parser3} = erlhttp:parse(Parser2),
    HeaderMap = map_headers(Result1, maps:new()),
    ?assertEqual(maps:get(<<"Host">>, HeaderMap), <<"www.example.com">>),
    ?assertEqual(maps:get(<<"Foo">>, HeaderMap), <<"bar">>),

    {done, done, _} = erlhttp:parse(Parser3).

simple_response_test() ->
    {ok, Parser} = erlhttp:new(response),
    Request = <<"HTTP/1.1 200 OK\r\n",
                "Host: www.example.com\r\nFoo: bar\r\nContent-Length: 0\r\n\r\n">>,

    {ok, Remaining, Parser1} = erlhttp:update(Request, Parser),
    ?assertEqual(length(binary:bin_to_list(Remaining)), 0),

    {response, Result, Parser2} = erlhttp:parse(Parser1),
    io:format("Result: ~p~n", [ Result ]),
    ?assert(lists:any(fun(V) -> V =:= {status_code, 200} end, Result)),
    ?assert(lists:any(fun(V) -> V =:= {version, {1, 1}} end, Result)),

    %?debugFmt("Parser2: ~p~n", [ Parser2 ]),
    {headers, Result1, Parser3} = erlhttp:parse(Parser2),
    HeaderMap = map_headers(Result1, maps:new()),
    ?assertEqual(maps:get(<<"Host">>, HeaderMap), <<"www.example.com">>),
    ?assertEqual(maps:get(<<"Foo">>, HeaderMap), <<"bar">>),

    {done, done, _} = erlhttp:parse(Parser3).

body_test() ->
    {ok, Parser} = erlhttp:new(),
    Request = <<"POST /hello HTTP/1.1\r\nHost: www.example.com\r\n",
                "Content-Length: 5\r\nContent-Type: text/plain\r\n",
                "\r\nHello">>,

    {ok, Remaining, Parser1} = erlhttp:update(Request, Parser),
    ?assertEqual(length(binary:bin_to_list(Remaining)), 0),

    %?debugFmt("Parsing: ~p~n", [ Parser1 ]),
    {request, Result, Parser2} = erlhttp:parse(Parser1),
    ?assert(lists:any(fun(V) -> V =:= {url, <<"/hello">>} end, Result)),
    ?assert(lists:any(fun(V) -> V =:= {method, post} end, Result)),
    ?assert(lists:any(fun(V) -> V =:= {version, {1, 1}} end, Result)),

    %?debugFmt("Parsing: ~p~n", [ Parser2 ]),
    {headers, Result1, Parser3} = erlhttp:parse(Parser2),
    HeaderMap = map_headers(Result1, maps:new()),
    ?assertEqual(maps:get(<<"Host">>, HeaderMap), <<"www.example.com">>),
    ?assertEqual(maps:get(<<"Content-Length">>, HeaderMap), <<"5">>),
    ?assertEqual(maps:get(<<"Content-Type">>, HeaderMap), <<"text/plain">>),

    %?debugFmt("Parsing: ~p~n", [ Parser3 ]),
    {body_chunk, Result2, Parser4} = erlhttp:parse(Parser3),
    ?assertEqual(Result2, <<"Hello">>),

    %?debugFmt("Parsing: ~p~n", [ Parser4 ]),
    {done, done, _} = erlhttp:parse(Parser4).

response_body_test() ->
    {ok, Parser} = erlhttp:new(response),
    Response = <<"HTTP/1.1 200 OK\r\n",
                 "Content-Length: 5\r\nContent-Type: text/plain\r\n",
                 "\r\nHello">>,

    {ok, Remaining, Parser1} = erlhttp:update(Response, Parser),
    ?assertEqual(length(binary:bin_to_list(Remaining)), 0),

    %?debugFmt("Parsing: ~p~n", [ Parser1 ]),
    {response, Result, Parser2} = erlhttp:parse(Parser1),
    ?assert(lists:any(fun(V) -> V =:= {status_code, 200} end, Result)),
    ?assert(lists:any(fun(V) -> V =:= {version, {1, 1}} end, Result)),

    %?debugFmt("Parsing: ~p~n", [ Parser2 ]),
    {headers, Result1, Parser3} = erlhttp:parse(Parser2),
    HeaderMap = map_headers(Result1, maps:new()),
    ?assertEqual(maps:get(<<"Content-Length">>, HeaderMap), <<"5">>),
    ?assertEqual(maps:get(<<"Content-Type">>, HeaderMap), <<"text/plain">>),

    %?debugFmt("Parsing: ~p~n", [ Parser3 ]),
    {body_chunk, Result2, Parser4} = erlhttp:parse(Parser3),
    ?assertEqual(Result2, <<"Hello">>),

    %?debugFmt("Parsing: ~p~n", [ Parser4 ]),
    {done, done, _} = erlhttp:parse(Parser4).

chunk_test() ->
    {ok, Parser} = erlhttp:new(),
    Request =
      <<"GET /foo/bar/baz HTTP/1.1\r\n",
        "Host: mybox\r\n",
        "User-Agent: Myself\r\n",
        "Transfer-Encoding: chunked\r\n",
        "\r\n",
        "d\r\n",
        "Hello, World!",
        "\r\n0\r\n\r\n">>,

    {ok, Remaining, Parser1} = erlhttp:update(Request, Parser),
    ?assertEqual(length(binary:bin_to_list(Remaining)), 0),

    %?debugFmt("Parsing: ~p~n", [ Parser1 ]),
    {request, Result, Parser2} = erlhttp:parse(Parser1),
    ?assert(lists:any(fun(V) -> V =:= {url, <<"/foo/bar/baz">>} end, Result)),
    ?assert(lists:any(fun(V) -> V =:= {method, get} end, Result)),
    ?assert(lists:any(fun(V) -> V =:= {version, {1, 1}} end, Result)),

    %?debugFmt("Parsing: ~p~n", [ Parser2 ]),
    {headers, Result1, Parser3} = erlhttp:parse(Parser2),
    HeaderMap = map_headers(Result1, maps:new()),
    ?assertEqual(maps:get(<<"Host">>, HeaderMap), <<"mybox">>),
    ?assertEqual(maps:get(<<"User-Agent">>, HeaderMap), <<"Myself">>),

    %?debugFmt("Parsing: ~p~n", [ Parser3 ]),
    {body_chunk, Result2, Parser4} = erlhttp:parse(Parser3),
    ?assertEqual(Result2, <<"Hello, World!">>),
    erlhttp:clear_body_results(Parser3),

    %?debugFmt("Parsing: ~p~n", [ Parser4 ]),
    {done, done, _} = erlhttp:parse(Parser4).

response_chunk_test() ->
    {ok, Parser} = erlhttp:new(response),
    Response =
      <<"HTTP/1.1 200 OK\r\n",
        "Transfer-Encoding: chunked\r\n",
        "\r\n",
        "d\r\n",
        "Hello, World!",
        "\r\n0\r\n\r\n">>,

    {ok, Remaining, Parser1} = erlhttp:update(Response, Parser),
    ?assertEqual(length(binary:bin_to_list(Remaining)), 0),

    %?debugFmt("Parsing: ~p~n", [ Parser1 ]),
    {response, Result, Parser2} = erlhttp:parse(Parser1),
    ?assert(lists:any(fun(V) -> V =:= {status_code, 200} end, Result)),
    ?assert(lists:any(fun(V) -> V =:= {version, {1, 1}} end, Result)),

    %?debugFmt("Parsing: ~p~n", [ Parser2 ]),
    {headers, _Result1, Parser3} = erlhttp:parse(Parser2),

    %?debugFmt("Parsing: ~p~n", [ Parser3 ]),
    {body_chunk, Result2, Parser4} = erlhttp:parse(Parser3),
    ?assertEqual(Result2, <<"Hello, World!">>),
    erlhttp:clear_body_results(Parser3),

    %?debugFmt("Parsing: ~p~n", [ Parser4 ]),
    {done, done, _} = erlhttp:parse(Parser4).

chunks_test() ->
    {ok, Parser} = erlhttp:new(),
    Request =
      <<"GET /foo/bar/baz HTTP/1.1\r\n",
        "Host: mybox\r\n",
        "User-Agent: Myself\r\n",
        "Transfer-Encoding: chunked\r\n",
        "\r\n",
        "d\r\n",
        "Hello, World!",
        "\r\n1b\r\n",
        " This is some chunked data.",
        "\r\n0\r\n\r\n">>,

    {ok, Remaining, Parser1} = erlhttp:update(Request, Parser),
    ?assertEqual(length(binary:bin_to_list(Remaining)), 0),

    %?debugFmt("Parsing: ~p~n", [ Parser1 ]),
    {request, Result, Parser2} = erlhttp:parse(Parser1),
    ?assert(lists:any(fun(V) -> V =:= {url, <<"/foo/bar/baz">>} end, Result)),
    ?assert(lists:any(fun(V) -> V =:= {method, get} end, Result)),
    ?assert(lists:any(fun(V) -> V =:= {version, {1, 1}} end, Result)),

    %?debugFmt("Parsing: ~p~n", [ Parser2 ]),
    {headers, Result1, Parser3} = erlhttp:parse(Parser2),
    HeaderMap = map_headers(Result1, maps:new()),
    ?assertEqual(maps:get(<<"Host">>, HeaderMap), <<"mybox">>),
    ?assertEqual(maps:get(<<"User-Agent">>, HeaderMap), <<"Myself">>),

    {body_chunk, Result2, Parser4} = erlhttp:parse(Parser3),
    ?assertEqual(Result2, <<"Hello, World! This is some chunked data.">>),
    erlhttp:clear_body_results(Parser3),

    {done, done, _} = erlhttp:parse(Parser4).

body_pipeline_test() ->
    {ok, Parser} = erlhttp:new(),
    Request = <<"POST /hello HTTP/1.1\r\nHost: www.example.com\r\n",
                "Content-Length: 5\r\nContent-Type: text/plain\r\n",
                "\r\nHello",
                "POST /hello HTTP/1.1\r\nHost: www.example.com\r\n",
                "Content-Length: 6\r\nContent-Type: text/plain\r\n",
                "\r\nWorld!">>,

    {ok, Remaining, Parser1} = erlhttp:update(Request, Parser),
    {request, _Result, Parser2} = erlhttp:parse(Parser1),
    {headers, _Result1, Parser3} = erlhttp:parse(Parser2),
    {body_chunk, Result2, Parser4} = erlhttp:parse(Parser3),
    ?assertEqual(Result2, <<"Hello">>),
    erlhttp:clear_body_results(Parser3),
    {done, done, _} = erlhttp:parse(Parser4),

    {ok, ParserA} = erlhttp:new(request),
    {ok, RemainingA, ParserA1} = erlhttp:update(Remaining, ParserA),
    ?assertEqual(length(binary:bin_to_list(RemainingA)), 0),
    {request, _ResultA1, ParserA2} = erlhttp:parse(ParserA1),
    {headers, _ResultA2, ParserA3} = erlhttp:parse(ParserA2),
    {body_chunk, ResultA3, ParserA4} = erlhttp:parse(ParserA3),
    ?assertEqual(ResultA3, <<"World!">>),
    erlhttp:clear_body_results(ParserA3),
    {done, done, _} = erlhttp:parse(ParserA4).

map_headers([Header | Headers], HeaderMap) ->
  {Key, Value} = Header,
  NewMap = maps:put(Key, Value, HeaderMap),
  map_headers(Headers, NewMap);

map_headers([], HeaderMap) ->
  HeaderMap.
