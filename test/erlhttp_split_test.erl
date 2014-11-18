-module(erlhttp_split_test).

-include_lib("eunit/include/eunit.hrl").

request_split_test() ->
  Request = <<"POST /hello HTTP/1.1\r\nHost: www.example.com\r\n",
              "Content-Length: 5\r\nContent-Type: text/plain\r\n",
              "\r\nHello">>,
  % There must be a better way to do this
  Len = length(binary_to_list(Request)),
  test_split(Request, request, 0, Len, <<>>, Request).

response_split_test() ->
  Response = <<"HTTP/1.1 200 OK\r\n",
              "Content-Length: 5\r\nContent-Type: text/plain\r\n",
              "\r\nHello">>,
  % There must be a better way to do this
  Len = length(binary_to_list(Response)),
  test_split(Response, response, 0, Len, <<>>, Response).

test_split(Request, Mode, 0, TotalLen, First, Last) ->
  ?debugFmt("test: 1", []),
  test_split(Request, Mode, 1, TotalLen,
             binary:part(Request, 0, 1),
             binary:part(Request, 1, (TotalLen - 1)));
test_split(Request, Mode, Pos, TotalLen, First, Last) ->
  ?debugFmt("test: ~p, ~p~n", [ Pos, TotalLen ]),
  %?debugFmt("First: ~p~n", [ First ]),
  %?debugFmt("Last: ~p~n", [ Last ]),
  {ok, EmptyParser} = erlhttp:new(Mode),
  {ok, <<>>, Parser} = erlhttp:update(First, EmptyParser),
  parse_test(new, Parser, Last, <<>>),

  NewPos = Pos + 1,
  case NewPos of
    TotalLen ->
      ok;
    _ ->
      test_split(Request, Mode, NewPos, TotalLen,
                 binary:part(Request, 0, NewPos),
                 binary:part(Request, NewPos, (TotalLen - NewPos)))
  end.

parse_test(new, Parser, Last, Body) ->
  case erlhttp:parse(Parser) of
    {request, Result, NewParser} ->
      ?assert(lists:any(fun(V) -> V =:= {url, <<"/hello">>} end, Result)),
      ?assert(lists:any(fun(V) -> V =:= {method, post} end, Result)),
      parse_test(headers, NewParser, Last, Body);
    {response, Result, NewParser} ->
      ?assert(lists:any(fun(V) -> V =:= {status_code, 200} end, Result)),
      parse_test(headers, NewParser, Last, Body);
    {more, NewParser} ->
      {ok, <<>>, NewerParser} = erlhttp:update(Last, NewParser),
      parse_test(new, NewerParser, <<>>, Body)
  end;

parse_test(headers, Parser, Last, Body) ->
  case erlhttp:parse(Parser) of
    {headers, Result, NewParser} ->
      Headers = map_headers(Result, maps:new()),
      ?assertEqual(maps:get(<<"Content-Type">>, Headers), <<"text/plain">>),
      parse_test(body_chunk, NewParser, Last, Body);
    {more, NewParser} ->
      {ok, <<>>, NewerParser} = erlhttp:update(Last, NewParser),
      parse_test(headers, NewerParser, <<>>, Body)
  end;

parse_test(body_chunk, Parser, Last, Body) ->
  case erlhttp:parse(Parser) of
    {body_chunk, Result, NewParser} ->
      %?debugFmt("body_chunk ~p ~p~n", [ Body, Result ]),
      NewBody = list_to_binary(binary_to_list(Body) ++ binary_to_list(Result)),
      parse_test(body_chunk, NewParser, Last, NewBody);
    {done, done, _} ->
      %?debugFmt("done~n", [ ]),
      ?assertEqual(Body, <<"Hello">>),
      ok;
    {more, NewParser} ->
      %?debugFmt("more ~n", [ ]),
      {ok, <<>>, NewerParser} = erlhttp:update(Last, NewParser),
      parse_test(body_chunk, NewerParser, <<>>, Body)
  end;

parse_test(done, done, _, _) ->
  ok.

map_headers([Header | Headers], HeaderMap) ->
  {Key, Value} = Header,
  NewMap = maps:put(Key, Value, HeaderMap),
  map_headers(Headers, NewMap);

map_headers([], HeaderMap) ->
  HeaderMap.
