# HTTP read benchmark

Run `bundle install` and `bundle exec ruby http.rb` from `benchmark/`.
For a smoke run: `SAMPLES=1 REQUESTS=3 bundle exec ruby http.rb`.

Compare checkouts using the same installed gems and script:

```sh
ruby -I /path/to/main/lib /path/to/benchmark/http.rb
ruby -I /path/to/pr/lib /path/to/benchmark/http.rb
```

The script prints the loaded io-stream path and HTTP parser version. It exercises
protocol-http1's HTTP/1.1 parser and streaming body reader through
IO::Stream::Buffered over TCP. IPv4 (`127.0.0.1`) and IPv6 (`::1`) run all cases,
without an address-family fallback.

Each sample uses one keep-alive connection and sequential GETs. A server thread
returns prebuilt Content-Length or chunked responses (chunks up to 16 KiB).
There are 2,000 requests per sample for 64 B and 16 KiB bodies, and 64 requests
for 1 MiB bodies. Connection setup and ten warm-up requests are excluded from
timing. Warm-up validates contents; every response checks status and body size.
GC remains enabled. Each sample has a 60-second timeout including setup.

Output reports the fastest of five samples, in requests/s and payload MiB/s.
The server shares the client's Ruby process. These local round-trip measurements
include server work, but no TLS, web framework, concurrency, or memory profiling.

## Local comparison

Ruby 4.0.9, protocol-http1 0.41.1; main `91437ae`, PR `25368d4`.
One full invocation per checkout, main first, best of five samples per case.
These individual measurements do not establish statistically significant changes.
Both IPv4 and IPv6 completed successfully.

| Family | Framing | Body | main requests/s | PR requests/s |
|---|---|---:|---:|---:|
| IPv4 | Content-Length | 64 B | 21,382 | 21,560 |
| IPv4 | Chunked | 64 B | 19,873 | 19,305 |
| IPv4 | Content-Length | 16 KiB | 19,929 | 19,552 |
| IPv4 | Chunked | 16 KiB | 17,106 | 16,911 |
| IPv4 | Content-Length | 1 MiB | 2,155 | 2,338 |
| IPv4 | Chunked | 1 MiB | 1,414 | 1,478 |
| IPv6 | Content-Length | 64 B | 21,745 | 22,469 |
| IPv6 | Chunked | 64 B | 19,154 | 19,560 |
| IPv6 | Content-Length | 16 KiB | 18,923 | 19,786 |
| IPv6 | Chunked | 16 KiB | 16,939 | 16,958 |
| IPv6 | Content-Length | 1 MiB | 2,323 | 2,172 |
| IPv6 | Chunked | 1 MiB | 1,547 | 1,509 |
