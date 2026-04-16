# DNdistresS

```text
           _____   _____       _ _                             _____
          |  __ \ |  __ \     | (_)       _                   / ____)
          | |  \ \| |  \ \  __| |_  ___ _| |_  ____ _____  __( (____
          | |   | | |   | |/ _  | |/___)_   _)/ ___) ___ |/___)____ \
          | |__/ /| |   | | |_| | |___ | | |_| |   | ____|___ |____) )
          |_____/ |_|   |_|\____|_(___/   \__)_|   |_____(___(______/

    DNdistresS Copyright (C) 2026 saint-lascivious (Hayden Pearce)

    This program comes with ABSOLUTELY NO WARRANTY; for details type 'show w'.
    This is free software, and you are welcome to redistribute it
    under certain conditions; type 'show c' for details.
```

---

## Index
- [general](#general)
- [usage](#usage)
- [topics](#topics)
- [info](#info)
- [description](#description)
- [runtime](#runtime)
- [resolver](#resolver)
- [install](#install)
- [uninstall](#uninstall)
- [show](#show)
- [version](#version)
- [binary](#binary)
- [burst](#burst)
- [column](#column)
- [custom](#custom)
- [directory](#directory)
- [duration](#duration)
- [file](#file)
- [format](#format)
- [local](#local)
- [location](#location)
- [maximum](#maximum)
- [output](#output)
- [port](#port)
- [qps](#qps)
- [remote](#remote)
- [seconds](#seconds)
- [top](#top)
- [type](#type)
- [url](#url)
- [verbosity](#verbosity)

## general

```text
Usage:
  dndistress [-b _BINARY] [-B _BURST] [-c _COLUMN] [-C _CUSTOM] \
             [-d _DIRECTORY] [-D _DURATION] [-f _FILE] [-F _FORMAT] [-h] \
             [-i _INSTALL] [-l _LOCAL] [-L _LOCATION] [-m _MAXIMUM] \
             [-o _OUTPUT] [-p _PORT] [-q _QPS] [-r _REMOTE] [-s _SECONDS] \
             [-S {w|c|warranty|conditions}] [-t _TOP] [-T _TYPE] \
             [-u _UNINSTALL] [-U _URL] [-v] [-V _VERBOSITY]

  dndistress --help [topic]
  dndistress help [topic]
  dndistress install [PATH]
  dndistress uninstall [PATH]
  dndistress show {w|c|warranty|conditions}
  dndistress --show {w|c|warranty|conditions}
  dndistress --show-warranty
  dndistress --show-conditions

Help:
  -h, --help [topic]

  help [topic]
      Show help for a specific topic. Topic can be a command or option.

      Reverse parsing is supported (examples):
        dndistress --help --install
        dndistress --install --help
        dndistress --help -q
        dndistress -q --help

Topic examples:
  general, info, description, runtime, resolver, install, uninstall, show, version,
  binary, burst, column, custom, directory, duration, file, format,
  local, location, maximum, output, port, qps, remote, seconds,
  top, type, url, verbosity

Tip:
  Run 'dndistress --help topics' to list all available topics.
```

## usage

```text
Usage:
  dndistress [-b _BINARY] [-B _BURST] [-c _COLUMN] [-C _CUSTOM] \
             [-d _DIRECTORY] [-D _DURATION] [-f _FILE] [-F _FORMAT] [-h] \
             [-i _INSTALL] [-l _LOCAL] [-L _LOCATION] [-m _MAXIMUM] \
             [-o _OUTPUT] [-p _PORT] [-q _QPS] [-r _REMOTE] [-s _SECONDS] \
             [-S {w|c|warranty|conditions}] [-t _TOP] [-T _TYPE] \
             [-u _UNINSTALL] [-U _URL] [-v] [-V _VERBOSITY]

  dndistress --help [topic]
  dndistress help [topic]
  dndistress install [PATH]
  dndistress uninstall [PATH]
  dndistress show {w|c|warranty|conditions}
  dndistress --show {w|c|warranty|conditions}
  dndistress --show-warranty
  dndistress --show-conditions

Help:
  -h, --help [topic]

  help [topic]
      Show help for a specific topic. Topic can be a command or option.

      Reverse parsing is supported (examples):
        dndistress --help --install
        dndistress --install --help
        dndistress --help -q
        dndistress -q --help

Topic examples:
  general, info, description, runtime, resolver, install, uninstall, show, version,
  binary, burst, column, custom, directory, duration, file, format,
  local, location, maximum, output, port, qps, remote, seconds,
  top, type, url, verbosity

Tip:
  Run 'dndistress --help topics' to list all available topics.
```

## topics

```text
Help topics:

  General:
    general usage topics info description runtime resolver

  Commands:
    install uninstall show version help

  Options:
    binary burst column custom directory duration file format
    local location maximum output port qps remote seconds
    top type url verbosity

Aliases accepted:
  -i/--install, -u/--uninstall, -v/--version, -h/--help, -S/--show,
  --show-warranty, --show-conditions,
  -b/-B/-c/-C/-d/-D/-f/-F/-l/-L/-m/-o/-p/-q/-r/-s/-t/-T/-U/-V
```

## info

```text
Topic: info

DNdistresS is a DNS query workload generator/stressor.

Intent:
  Provide reproducible DNS query load against a chosen resolver,
  with explicit control over request rate, burst behavior, runtime,
  worker concurrency, and query type.

Typical use:
  - Resolver smoke/load testing
  - Cache warmup exercises
  - Throughput/latency behavior checks under steady or bursty load

Data path:
  source (url/file/custom) -> parse -> dedupe -> top-N -> dispatch -> query workers
```

## description

```text
Topic: description

DNdistresS continuously (or time-bounded) sends DNS queries from a prepared
domain list, using a token-bucket scheduler and a worker pool.

Key properties:
  - Deterministic rate shaping via qps + burst
  - Parallel execution via maximum workers
  - Flexible source handling (download/cache/file/custom list)
  - Resolver targeting (local/remote, IPv4/IPv6, optional port override)
  - Query tool selection (dig/nslookup) and RR type selection

A practical resolver workload tool for controlled DNS traffic generation.
```

## runtime

```text
Topic: runtime

Core execution path:
  fetch source -> parse domains -> dedupe/top-N -> token-bucket dispatch -> DNS query workers

Primary controls:
  -q/--qps          tokens per second
  -B/--burst        burst ceiling
  -m/--maximum      worker count
  -D/--duration     runtime seconds (0 = forever)
  -o/--output       quiet|answer

Timer guard:
  When running under dndistress.service from dndistress.timer,
  _DURATION is clamped to the timer period (OnUnitActiveSec).
  _DURATION=0 is also clamped (not treated as infinite).
```

## resolver

```text
Topic: resolver

Resolver controls:
  -L/--location     local|remote
  -l/--local        local resolver address
  -r/--remote       remote resolver address
  -p/--port         DNS port (1..65535)

Address forms accepted by -l/-r:
  IPv4
  IPv6
  host#port
  [ipv6]:port
```

## install

```text
Topic: install

Usage:
  dndistress install [PATH]
  dndistress -i [PATH]
  dndistress --install [PATH]

Default PATH: /usr/local/bin

Installs script + service + timer, then enables and starts dndistress.timer.
```

## uninstall

```text
Topic: uninstall

Usage:
  dndistress uninstall [PATH]
  dndistress -u [PATH]
  dndistress --uninstall [PATH]

Default PATH: /usr/local/bin

Removes script + service + timer, disables/stops units, daemon-reloads systemd.
```

## show

```text
Topic: show

Usage:
  show {w|c|warranty|conditions}
  -S {w|c|warranty|conditions}
  --show {w|c|warranty|conditions}
  --show-warranty
  --show-conditions

Meaning:
  Show GPL warranty or GPL conditions excerpt.

Examples:
  dndistress show w
  dndistress --show conditions
  dndistress --show-warranty
```

## version

```text
Topic: version

Usage:
  -v | --version | version

Prints tool version and exits.
```

## binary

```text
Topic: binary (-b, --binary)

Values:
  auto | dig | nslookup

Default: auto

auto selects dig first, then nslookup.
```

## burst

```text
Topic: burst (-B, --burst)

Meaning:
  Max burst size for token bucket.

Default: 32

Validation: positive integer.
```

## column

```text
Topic: column (-c, --column)

Meaning:
  CSV column index when reading file/url source.

Default: 0

0 means auto-detect.

Validation: non-negative integer.
```

## custom

```text
Topic: custom (-C, --custom)

Meaning:
  Custom domain file prepended to primary source before dedupe/top-N.

Default: /home/saint/.cache/dndistress/custom.txt
```

## directory

```text
Topic: directory (-d, --directory)

Meaning:
  Cache/work directory for downloaded sources and cache files.

Default: /home/saint/.cache/dndistress
```

## duration

```text
Topic: duration (-D, --duration)

Meaning:
  Runtime length in seconds.

Default: 60

0 = continuous loop.

Note: Also accepts plain seconds or human-readable duration (e.g. 1d 2h 3m 4s).

Timer guard:
  Under dndistress.service + dndistress.timer, _DURATION is clamped
  to the timer period (OnUnitActiveSec), including _DURATION=0.
  Optional override for period detection: _TIMER_PERIOD (duration syntax).
```

## file

```text
Topic: file (-f, --file)

Meaning:
  Use local input file; overrides URL download path.

Default: (empty)

Must be readable.
```

## format

```text
Topic: format (-F, --format)

Values:
  auto | plain | csv

Default: auto
```

## local

```text
Topic: local resolver (-l, --local)

Meaning:
  Local resolver address. Also sets location=local.

Accepted:
  IPv4/IPv6, optional #port or [ipv6]:port.

Default: 127.0.0.1
```

## location

```text
Topic: location (-L, --location)

Values:
  local | remote

Default: local

Controls whether _LOCAL or _REMOTE is used as resolver.
```

## maximum

```text
Topic: maximum workers (-m, --maximum)

Meaning:
  Max concurrent query workers.

Default: 24

Validation: positive integer, clamped to 128.
```

## output

```text
Topic: output (-o, --output)

Values:
  quiet | answer

Default: quiet

quiet suppresses answer output; answer prints response records.
```

## port

```text
Topic: port (-p, --port)

Meaning:
  DNS service port used by query tool.

Default: 53

Range: 1..65535.
```

## qps

```text
Topic: qps (-q, --qps)

Meaning:
  Token refill rate (queries/sec target).

Default: 80

Validation: positive integer.
```

## remote

```text
Topic: remote resolver (-r, --remote)

Meaning:
  Remote resolver address. Also sets location=remote.

Accepted:
  IPv4/IPv6, optional #port or [ipv6]:port.

Default: 
```

## seconds

```text
Topic: seconds cache TTL (-s, --seconds)

Meaning:
  Cache TTL for downloaded source.

Default: 86400

0 disables cache.

Note: Also accepts plain seconds or human-readable duration (e.g. 5d 6h 7m 8s).
```

## top

```text
Topic: top (-t, --top)

Meaning:
  Keep top N domains after dedupe.

Default: 10000

Validation: positive integer.
```

## type

```text
Topic: type (-T, --type)

Meaning:
  DNS RR type for dig/nslookup (A, AAAA, MX, TXT, etc).

Default: A

Also accepted:
  Numeric RR type IDs (examples: 1, 28, 15, 65, 257).
  Numeric IDs are mapped to known mnemonics.

Note:
  ANY is intentionally rejected (including ID 255).
```

## url

```text
Topic: url (-U, --url)

Meaning:
  Source URL used when -f/--file is not provided.

Default: https://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip
```

## verbosity

```text
Topic: verbosity (-V, --verbosity)

Values:
  0=CRITICAL
  1=ERROR
  2=WARNING
  3=INFO
  4=DEBUG

Default: 1
```

---

> Generated by `./scripts/dndistress-doc-gen.sh` on 2026-04-16 06:59:30 UTC.
